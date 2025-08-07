#!/usr/bin/env python3
"""
Resource Monitoring and Alerting System
Provides real-time resource monitoring and user-friendly alerts
"""

import time
import psutil
import threading
from typing import Dict, Any, List, Optional, Callable
from dataclasses import dataclass, asdict
from enum import Enum
import json
import os
import gc

class AlertLevel(Enum):
    """Alert severity levels"""
    INFO = "info"
    WARNING = "warning"
    CRITICAL = "critical"
    EMERGENCY = "emergency"

class ResourceType(Enum):
    """Types of resources being monitored"""
    MEMORY = "memory"
    CPU = "cpu"
    GPU = "gpu"
    DISK = "disk"
    NETWORK = "network"

@dataclass
class ResourceAlert:
    """Resource alert information"""
    level: AlertLevel
    resource_type: ResourceType
    message: str
    current_value: float
    threshold: float
    unit: str
    recommendation: str
    timestamp: float
    alert_id: str

@dataclass
class ResourceMetrics:
    """Current resource metrics"""
    memory_available_gb: float
    memory_used_percent: float
    cpu_percent: float
    gpu_memory_available_gb: Optional[float] = None
    gpu_memory_used_percent: Optional[float] = None
    disk_free_gb: Optional[float] = None
    disk_used_percent: Optional[float] = None

class ResourceMonitor:
    """Comprehensive resource monitoring and alerting system"""
    
    def __init__(self, device_type: str = "auto", device_detector=None):
        self.device_type = device_type
        self.device_detector = device_detector  # Optional device detector integration
        self.monitoring = False
        self.monitor_thread = None
        self.alert_callbacks: List[Callable] = []
        self.alert_history: List[ResourceAlert] = []
        
        # Resource thresholds (configurable)
        self.thresholds = {
            "memory_warning": 6.0,    # GB available
            "memory_critical": 3.0,   # GB available
            "cpu_warning": 80.0,      # % usage
            "cpu_critical": 90.0,     # % usage
        }
        
        # Performance tiers for different resource levels
        self.performance_tiers = {
            "optimal": {"memory": 12.0, "cpu": 50.0, "desc": "Full speed generation"},
            "good": {"memory": 8.0, "cpu": 70.0, "desc": "Slightly reduced speed"},
            "moderate": {"memory": 6.0, "cpu": 80.0, "desc": "Noticeable slowdown"},
            "slow": {"memory": 4.0, "cpu": 90.0, "desc": "Significant delays"},
            "critical": {"memory": 2.0, "cpu": 95.0, "desc": "May fail or crash"}
        }
        
        # Device-specific adjustments
        if self.device_detector:
            self._adjust_thresholds_for_device()
        
        print("🔍 Resource Monitor initialized")
    
    def _adjust_thresholds_for_device(self):
        """Adjust thresholds based on device capabilities"""
        if not self.device_detector:
            print(f"⚠️ No device detector available, using default thresholds")
            return
            
        device = self.device_detector.best_device
        allocation = self.device_detector.resource_allocation
        
        print(f"🔧 Adjusting thresholds for {device.upper()}")
        
        # Store original thresholds for comparison
        original_warning = self.thresholds["memory_warning"]
        original_critical = self.thresholds["memory_critical"]
        
        if device == "mps":
            # MPS has memory limitations - be more conservative
            self.thresholds["memory_warning"] = 4.0  # Reduced from 6.0
            self.thresholds["memory_critical"] = 2.0  # Reduced from 3.0
            print(f"   MPS thresholds: Warning={self.thresholds['memory_warning']}GB, Critical={self.thresholds['memory_critical']}GB")
            
        elif device == "cpu":
            # CPU can handle more memory pressure
            self.thresholds["memory_warning"] = 8.0  # Increased from 6.0
            self.thresholds["memory_critical"] = 4.0  # Increased from 3.0
            print(f"   CPU thresholds: Warning={self.thresholds['memory_warning']}GB, Critical={self.thresholds['memory_critical']}GB")
            
        else:
            # For other devices, use moderate thresholds
            self.thresholds["memory_warning"] = 6.0  # Default
            self.thresholds["memory_critical"] = 3.0  # Default
            print(f"   {device.upper()} thresholds: Warning={self.thresholds['memory_warning']}GB, Critical={self.thresholds['memory_critical']}GB")
        
        # Adjust based on allocation strategy
        if allocation.use_conservative:
            # More conservative thresholds for conservative mode
            self.thresholds["memory_warning"] *= 1.2
            self.thresholds["memory_critical"] *= 1.2
            print(f"   Conservative mode: Increased thresholds by 20%")
        
        # Show the change
        print(f"   Thresholds adjusted: {original_warning}GB → {self.thresholds['memory_warning']}GB (warning)")
        print(f"   Thresholds adjusted: {original_critical}GB → {self.thresholds['memory_critical']}GB (critical)")
    
    def add_alert_callback(self, callback: Callable[[ResourceAlert], None]):
        """Add a callback function to handle alerts"""
        self.alert_callbacks.append(callback)
    
    def get_current_thresholds(self) -> Dict[str, float]:
        """Get current threshold values for debugging"""
        return self.thresholds.copy()
    
    def force_threshold_adjustment(self):
        """Force re-adjustment of thresholds based on current device detector"""
        if self.device_detector:
            print(f"🔄 Forcing threshold re-adjustment...")
            self._adjust_thresholds_for_device()
        else:
            print(f"⚠️ Cannot adjust thresholds: no device detector available")
    
    def get_current_metrics(self) -> Dict[str, float]:
        """Get current resource metrics"""
        memory = psutil.virtual_memory()
        return {
            "memory_available_gb": memory.available / (1024**3),
            "memory_used_percent": memory.percent,
            "cpu_percent": psutil.cpu_percent(interval=0.1)
        }
    
    def optimize_memory(self):
        """Optimize memory allocation with dynamic resource management"""
        try:
            # Get current memory info
            memory_info = self.get_memory_info()
            device_config = self.device_detector.generate_config()
            
            print(f"🔧 Dynamic Memory Optimization:")
            print(f"   Current Usage: {memory_info['used_gb']:.1f}GB")
            print(f"   Available: {memory_info['available_gb']:.1f}GB")
            print(f"   Allocated: {self.max_memory_gb:.1f}GB")
            print(f"   Other Apps: {memory_info['other_apps_gb']:.1f}GB")
            
            # Enhanced MPS memory management with dynamic allocation
            if self.device == "mps":
                try:
                    import torch.mps
                    
                    # Get optimal memory fraction
                    memory_fraction = self.device_detector.resource_allocation.memory_fraction
                    print(f"✅ MPS memory fraction set to {memory_fraction*100:.1f}%")
                    
                    # Clear cache more aggressively
                    if hasattr(torch.mps, 'empty_cache'):
                        torch.mps.empty_cache()
                    
                    # Force garbage collection
                    gc.collect()
                    
                    # Set memory limits dynamically
                    if hasattr(torch.mps, 'set_per_process_memory_fraction'):
                        torch.mps.set_per_process_memory_fraction(memory_fraction)
                except ImportError:
                    print("⚠️ torch.mps not available for MPS optimization")
            
            # Standard memory optimization
            try:
                import torch
                if hasattr(torch, 'cuda') and torch.cuda.is_available():
                    torch.cuda.empty_cache()
            except ImportError:
                print("⚠️ torch not available for CUDA optimization")
            
            # Force garbage collection
            gc.collect()
            
            # Get memory info after optimization
            memory_after = self.get_memory_info()
            print(f"📊 Memory after optimization: {memory_after['used_gb']:.1f}GB used, {memory_after['available_gb']:.1f}GB available")
            
        except Exception as e:
            print(f"⚠️ Memory optimization failed: {e}")
    
    def check_alerts(self) -> List[ResourceAlert]:
        """Check for resource alerts based on current metrics"""
        metrics = self.get_current_metrics()
        alerts = []
        
        # Memory alerts - use current thresholds
        current_warning_threshold = self.thresholds["memory_warning"]
        current_critical_threshold = self.thresholds["memory_critical"]
        
        # Debug: Show what thresholds are being used
        print(f"🔍 Alert Check - Current thresholds: Warning={current_warning_threshold}GB, Critical={current_critical_threshold}GB")
        print(f"🔍 Alert Check - Available memory: {metrics['memory_available_gb']:.1f}GB")
        
        if metrics["memory_available_gb"] <= current_critical_threshold:
            alerts.append(ResourceAlert(
                level=AlertLevel.CRITICAL,
                resource_type=ResourceType.MEMORY,
                message=f"🚨 CRITICAL: Only {metrics['memory_available_gb']:.1f}GB memory available!",
                recommendation="Close applications immediately or restart system",
                current_value=metrics["memory_available_gb"],
                threshold=current_critical_threshold,
                unit="GB",
                timestamp=time.time(),
                alert_id=f"memory_{int(time.time())}"
            ))
        elif metrics["memory_available_gb"] <= current_warning_threshold:
            alerts.append(ResourceAlert(
                level=AlertLevel.WARNING,
                resource_type=ResourceType.MEMORY,
                message=f"⚠️ WARNING: Low memory ({metrics['memory_available_gb']:.1f}GB available)",
                recommendation="Close some applications for better performance",
                current_value=metrics["memory_available_gb"],
                threshold=current_warning_threshold,
                unit="GB",
                timestamp=time.time(),
                alert_id=f"memory_{int(time.time())}"
            ))
        
        # CPU alerts
        current_cpu_warning = self.thresholds["cpu_warning"]
        current_cpu_critical = self.thresholds["cpu_critical"]
        
        print(f"🔍 Alert Check - CPU thresholds: Warning={current_cpu_warning}%, Critical={current_cpu_critical}%")
        print(f"🔍 Alert Check - Current CPU: {metrics['cpu_percent']:.1f}%")
        
        if metrics["cpu_percent"] >= current_cpu_critical:
            alerts.append(ResourceAlert(
                level=AlertLevel.CRITICAL,
                resource_type=ResourceType.CPU,
                message=f"🚨 CRITICAL: CPU usage at {metrics['cpu_percent']:.1f}%!",
                recommendation="Close CPU-intensive applications immediately",
                current_value=metrics["cpu_percent"],
                threshold=current_cpu_critical,
                unit="%",
                timestamp=time.time(),
                alert_id=f"cpu_{int(time.time())}"
            ))
        elif metrics["cpu_percent"] >= current_cpu_warning:
            alerts.append(ResourceAlert(
                level=AlertLevel.WARNING,
                resource_type=ResourceType.CPU,
                message=f"⚠️ WARNING: High CPU usage ({metrics['cpu_percent']:.1f}%)",
                recommendation="Consider closing some applications",
                current_value=metrics["cpu_percent"],
                threshold=current_cpu_warning,
                unit="%",
                timestamp=time.time(),
                alert_id=f"cpu_{int(time.time())}"
            ))
        
        # Get disk info
        try:
            disk = psutil.disk_usage('/')
            disk_free_gb = disk.free / (1024**3)
            disk_used_percent = (disk.used / disk.total) * 100
            if disk_free_gb <= self.thresholds["memory_critical"]:
                alerts.append(ResourceAlert(
                    level=AlertLevel.CRITICAL,
                    resource_type=ResourceType.DISK,
                    message=f"⚠️ CRITICAL: Disk space critically low ({disk_free_gb:.1f}GB free)",
                    recommendation="Free up disk space immediately to prevent crashes",
                    current_value=disk_free_gb,
                    threshold=self.thresholds["memory_critical"],
                    unit="GB",
                    timestamp=time.time(),
                    alert_id=f"disk_{int(time.time())}"
                ))
            elif disk_free_gb <= self.thresholds["memory_warning"]:
                alerts.append(ResourceAlert(
                    level=AlertLevel.WARNING,
                    resource_type=ResourceType.DISK,
                    message=f"⚠️ WARNING: Disk space getting low ({disk_free_gb:.1f}GB free)",
                    recommendation="Consider freeing up disk space",
                    current_value=disk_free_gb,
                    threshold=self.thresholds["memory_warning"],
                    unit="GB",
                    timestamp=time.time(),
                    alert_id=f"disk_{int(time.time())}"
                ))
        except Exception:
            pass
        
        # Get GPU info if available
        try:
            import torch
            if torch.cuda.is_available():
                gpu_memory = torch.cuda.get_device_properties(0).total_memory
                gpu_memory_allocated = torch.cuda.memory_allocated(0)
                gpu_memory_available_gb = (gpu_memory - gpu_memory_allocated) / (1024**3)
                gpu_memory_used_percent = (gpu_memory_allocated / gpu_memory) * 100
                if gpu_memory_available_gb <= self.thresholds["memory_critical"]:
                    alerts.append(ResourceAlert(
                        level=AlertLevel.CRITICAL,
                        resource_type=ResourceType.GPU,
                        message=f"⚠️ CRITICAL: GPU memory critically low ({gpu_memory_available_gb:.1f}GB available)",
                        recommendation="Close GPU-intensive applications or reduce model size",
                        current_value=gpu_memory_available_gb,
                        threshold=self.thresholds["memory_critical"],
                        unit="GB",
                        timestamp=time.time(),
                        alert_id=f"gpu_{int(time.time())}"
                    ))
                elif gpu_memory_available_gb <= self.thresholds["memory_warning"]:
                    alerts.append(ResourceAlert(
                        level=AlertLevel.WARNING,
                        resource_type=ResourceType.GPU,
                        message=f"⚠️ WARNING: GPU memory getting low ({gpu_memory_available_gb:.1f}GB available)",
                        recommendation="Consider closing GPU-intensive applications",
                        current_value=gpu_memory_available_gb,
                        threshold=self.thresholds["memory_warning"],
                        unit="GB",
                        timestamp=time.time(),
                        alert_id=f"gpu_{int(time.time())}"
                    ))
            elif hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
                # For MPS, we estimate based on system memory
                gpu_memory_available_gb = metrics["memory_available_gb"] * 0.3
                gpu_memory_used_percent = metrics["memory_used_percent"]
        except Exception:
            pass
        
        return alerts
    
    def get_performance_tier(self) -> Dict[str, Any]:
        """Get current performance tier based on resource availability"""
        metrics = self.get_current_metrics()
        
        if (metrics["memory_available_gb"] >= 12.0 and metrics["cpu_percent"] <= 50.0):
            tier = "optimal"
        elif (metrics["memory_available_gb"] >= 8.0 and metrics["cpu_percent"] <= 70.0):
            tier = "good"
        elif (metrics["memory_available_gb"] >= 6.0 and metrics["cpu_percent"] <= 80.0):
            tier = "moderate"
        elif (metrics["memory_available_gb"] >= 4.0 and metrics["cpu_percent"] <= 90.0):
            tier = "slow"
        else:
            tier = "critical"
        
        tier_info = self.performance_tiers[tier].copy()
        tier_info["tier"] = tier
        tier_info["current_metrics"] = metrics
        
        return tier_info
    
    def get_recommendations(self) -> List[str]:
        """Get specific recommendations for improving performance"""
        metrics = self.get_current_metrics()
        recommendations = []
        
        if metrics["memory_available_gb"] < 8.0:
            recommendations.append("💾 Close memory-intensive apps (browsers, IDEs)")
        if metrics["memory_available_gb"] < 4.0:
            recommendations.append("💾 Restart computer to free memory")
        if metrics["cpu_percent"] > 80:
            recommendations.append("🖥️ Close CPU-intensive apps (video editors, games)")
        if metrics["cpu_percent"] > 90:
            recommendations.append("🖥️ Avoid running multiple AI models")
        
        if not recommendations:
            recommendations.append("✅ System resources are optimal")
        
        return recommendations
    
    def start_monitoring(self, interval: float = 5.0):
        """Start continuous resource monitoring"""
        if self.monitoring:
            return
        
        self.monitoring = True
        self.monitor_thread = threading.Thread(
            target=self._monitor_loop, args=(interval,), daemon=True
        )
        self.monitor_thread.start()
        print(f"🔍 Resource monitoring started (interval: {interval}s)")
    
    def stop_monitoring(self):
        """Stop continuous resource monitoring"""
        self.monitoring = False
        if self.monitor_thread:
            self.monitor_thread.join(timeout=1.0)
        print("🔍 Resource monitoring stopped")
    
    def _monitor_loop(self, interval: float):
        """Main monitoring loop"""
        last_alert_time = {}  # Track last alert time per type to avoid spam
        
        while self.monitoring:
            try:
                alerts = self.check_alerts()
                
                # Process alerts (avoid spam by limiting frequency)
                for alert in alerts:
                    alert_key = f"{alert.resource_type.value}_{alert.level.value}"
                    current_time = time.time()
                    
                    # Only send alert if enough time has passed since last similar alert
                    if (alert_key not in last_alert_time or 
                        current_time - last_alert_time[alert_key] > 30.0):  # 30 second cooldown
                        
                        # Store alert
                        self.alert_history.append(alert)
                        last_alert_time[alert_key] = current_time
                        
                        # Call alert callbacks
                        for callback in self.alert_callbacks:
                            try:
                                callback(alert)
                            except Exception as e:
                                print(f"⚠️ Alert callback error: {e}")
                
                time.sleep(interval)
                
            except Exception as e:
                print(f"⚠️ Resource monitoring error: {e}")
                time.sleep(interval)
    
    def get_status_report(self) -> Dict[str, Any]:
        """Get comprehensive status report"""
        metrics = self.get_current_metrics()
        performance_tier = self.get_performance_tier()
        recommendations = self.get_recommendations()
        
        return {
            "timestamp": time.time(),
            "metrics": metrics,
            "performance_tier": performance_tier,
            "recommendations": recommendations,
            "recent_alerts": [
                asdict(alert) for alert in self.alert_history[-5:]  # Last 5 alerts
            ],
            "monitoring_active": self.monitoring
        }

    def get_device_aware_metrics(self) -> Dict[str, Any]:
        """Get metrics with device-specific context"""
        metrics = self.get_current_metrics()
        
        if self.device_detector:
            device_info = {
                "device_type": self.device_detector.best_device,
                "device_name": self.device_detector.devices[self.device_detector.best_device].device_name,
                "performance_tier": self.device_detector.devices[self.device_detector.best_device].performance_tier,
                "allocation": {
                    "recommended_memory_gb": self.device_detector.resource_allocation.recommended_memory_gb,
                    "conservative_mode": self.device_detector.resource_allocation.use_conservative,
                    "batch_size": self.device_detector.resource_allocation.batch_size
                }
            }
            metrics.update(device_info)
        
        return metrics

# Default alert handlers
def console_alert_handler(alert: ResourceAlert):
    """Default console alert handler"""
    print(f"\n{alert.message}")
    print(f"   Recommendation: {alert.recommendation}")
    print(f"   Current: {alert.current_value:.1f}{alert.unit}")
    print(f"   Threshold: {alert.threshold:.1f}{alert.unit}")
    
    # Add context about the threshold
    if alert.resource_type == ResourceType.MEMORY:
        if alert.threshold > 6.0:
            print(f"   Note: Using device-adjusted threshold (CPU + conservative mode)")
        elif alert.threshold < 4.0:
            print(f"   Note: Using device-adjusted threshold (MPS + conservative mode)")
        else:
            print(f"   Note: Using standard threshold")
    elif alert.resource_type == ResourceType.CPU:
        print(f"   Note: Using standard CPU threshold")
    
    print()

def json_alert_handler(alert: ResourceAlert):
    """JSON alert handler for API responses"""
    return asdict(alert)

# Global monitor instance
_global_monitor = None

def get_global_monitor() -> ResourceMonitor:
    """Get or create global resource monitor instance"""
    global _global_monitor
    if _global_monitor is None:
        _global_monitor = ResourceMonitor()
        # Add default console handler
        _global_monitor.add_alert_callback(console_alert_handler)
        print("🌐 Global Resource Monitor created")
    else:
        print("🌐 Using existing Global Resource Monitor")
    return _global_monitor

def get_global_monitor_with_device(device_detector) -> ResourceMonitor:
    """Get global monitor and ensure it has device detector integration"""
    monitor = get_global_monitor()
    
    # Update device detector if provided
    if device_detector and not monitor.device_detector:
        monitor.device_detector = device_detector
        monitor.force_threshold_adjustment()
        print("🌐 Global monitor updated with device detector")
    
    return monitor

def start_global_monitoring(interval: float = 5.0):
    """Start global resource monitoring"""
    monitor = get_global_monitor()
    if not monitor.monitoring:
        monitor.start_monitoring(interval)
        print(f"🌐 Global monitoring started (interval: {interval}s)")
    else:
        print("🌐 Global monitoring already active")

def stop_global_monitoring():
    """Stop global resource monitoring"""
    global _global_monitor
    if _global_monitor and _global_monitor.monitoring:
        _global_monitor.stop_monitoring()
        print("🌐 Global monitoring stopped")
    else:
        print("🌐 Global monitoring not active")

if __name__ == "__main__":
    # Test the resource monitor
    print("🧪 Testing Resource Monitor")
    print("=" * 50)
    
    monitor = ResourceMonitor()
    
    # Add test callback
    def test_callback(alert: ResourceAlert):
        print(f"🔔 TEST ALERT: {alert.message}")
    
    monitor.add_alert_callback(test_callback)
    
    # Get initial status
    print("\n📊 Initial Status:")
    status = monitor.get_status_report()
    print(f"Performance Tier: {status['performance_tier']['tier']}")
    print(f"Memory Available: {status['metrics']['memory_available_gb']:.1f}GB")
    print(f"CPU Usage: {status['metrics']['cpu_percent']:.1f}%")
    
    # Show recommendations
    print(f"\n💡 Recommendations:")
    for rec in status['recommendations']:
        print(f"   {rec}")
    
    # Start monitoring for 10 seconds
    print(f"\n🔍 Starting monitoring for 10 seconds...")
    monitor.start_monitoring(interval=2.0)
    time.sleep(10)
    monitor.stop_monitoring()
    
    print(f"\n📋 Alert History:")
    for alert in monitor.alert_history:
        print(f"   {alert.message}")
    
    print(f"\n✅ Resource monitor test completed!") 