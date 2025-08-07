#!/usr/bin/env python3
"""
Device Detection and Resource Validation Script
Tests system capabilities and validates memory allocation strategies
before loading the main model server.
"""

import os
import sys
import time
import json
import psutil
import torch
import gc
import subprocess
import re
from typing import Dict, Any, List, Optional
from dataclasses import dataclass, asdict

# Set MPS memory management environment variables
os.environ["PYTORCH_MPS_HIGH_WATERMARK_RATIO"] = "0.0"
os.environ["PYTORCH_MPS_LOW_WATERMARK_RATIO"] = "0.0"

@dataclass
class SystemInfo:
    """System information and capabilities"""
    platform: str
    cpu_cores: int
    total_memory_gb: float
    available_memory_gb: float
    cpu_percent: float
    disk_free_gb: float

@dataclass
class DeviceInfo:
    """Device-specific information"""
    device_type: str
    device_name: str
    memory_gb: float
    performance_tier: str
    supported: bool
    error_message: Optional[str] = None

@dataclass
class ResourceAllocation:
    """Resource allocation strategy"""
    recommended_memory_gb: float
    conservative_memory_gb: float
    memory_fraction: float
    batch_size: int
    attention_heads: int
    hidden_size: int
    use_conservative: bool
    safety_margin_gb: float

@dataclass
class ProcessInfo:
    """Information about other processes"""
    name: str
    memory_mb: float
    cpu_percent: float
    is_gpu_intensive: bool

class DeviceDetector:
    """Comprehensive device detection and resource validation"""
    
    def __init__(self):
        self.system_info = self._get_system_info()
        self.devices = self._detect_all_devices()
        self.other_processes = self._detect_other_processes()
        self.best_device = self._select_best_device()
        self.resource_allocation = self._calculate_resource_allocation()
        
    def _get_system_info(self) -> SystemInfo:
        """Get comprehensive system information"""
        memory = psutil.virtual_memory()
        cpu_percent = psutil.cpu_percent(interval=1)
        disk = psutil.disk_usage('/')
        
        return SystemInfo(
            platform=sys.platform,
            cpu_cores=psutil.cpu_count(),
            total_memory_gb=memory.total / (1024**3),
            available_memory_gb=memory.available / (1024**3),
            cpu_percent=cpu_percent,
            disk_free_gb=disk.free / (1024**3)
        )
    
    def _detect_all_devices(self) -> Dict[str, DeviceInfo]:
        """Detect all available devices"""
        devices = {}
        
        # Detect MPS (Apple Silicon)
        devices['mps'] = self._detect_mps_device()
        
        # Detect CUDA
        devices['cuda'] = self._detect_cuda_device()
        
        # Detect ROCm
        devices['rocm'] = self._detect_rocm_device()
        
        # Detect CPU
        devices['cpu'] = self._detect_cpu_device()
        
        return devices
    
    def _detect_mps_device(self) -> DeviceInfo:
        """Detect Apple Silicon MPS capabilities"""
        try:
            if not torch.backends.mps.is_available():
                return DeviceInfo(
                    device_type="mps",
                    device_name="Apple Silicon MPS",
                    memory_gb=0,
                    performance_tier="Unsupported",
                    supported=False,
                    error_message="MPS not available"
                )
            
            # Get GPU info using system_profiler
            gpu_name = "Apple Silicon"
            memory_gb = self.system_info.total_memory_gb * 0.8  # Estimate
            
            try:
                result = subprocess.run(['system_profiler', 'SPDisplaysDataType'], 
                                      capture_output=True, text=True, timeout=10)
                if result.returncode == 0:
                    output = result.stdout
                    gpu_match = re.search(r'Chipset Model:\s*(.+)', output)
                    if gpu_match:
                        gpu_name = gpu_match.group(1).strip()
                        
                        # Determine performance tier
                        gpu_lower = gpu_name.lower()
                        if 'ultra' in gpu_lower:
                            performance_tier = "Ultra"
                            memory_gb = min(32, self.system_info.total_memory_gb * 0.85)
                        elif 'max' in gpu_lower:
                            performance_tier = "Pro"
                            memory_gb = min(20, self.system_info.total_memory_gb * 0.8)
                        elif 'pro' in gpu_lower:
                            performance_tier = "Pro"
                            memory_gb = min(16, self.system_info.total_memory_gb * 0.75)
                        else:
                            performance_tier = "Standard"
                            memory_gb = min(12, self.system_info.total_memory_gb * 0.7)
                    else:
                        performance_tier = "Standard"
            except Exception as e:
                performance_tier = "Standard"
                print(f"⚠️ Could not get detailed MPS info: {e}")
            
            return DeviceInfo(
                device_type="mps",
                device_name=gpu_name,
                memory_gb=memory_gb,
                performance_tier=performance_tier,
                supported=True
            )
            
        except Exception as e:
            return DeviceInfo(
                device_type="mps",
                device_name="Apple Silicon MPS",
                memory_gb=0,
                performance_tier="Error",
                supported=False,
                error_message=str(e)
            )
    
    def _detect_cuda_device(self) -> DeviceInfo:
        """Detect NVIDIA CUDA capabilities"""
        try:
            if not torch.cuda.is_available():
                return DeviceInfo(
                    device_type="cuda",
                    device_name="NVIDIA CUDA",
                    memory_gb=0,
                    performance_tier="Unsupported",
                    supported=False,
                    error_message="CUDA not available"
                )
            
            gpu_name = torch.cuda.get_device_name(0)
            gpu_memory = torch.cuda.get_device_properties(0).total_memory
            memory_gb = gpu_memory / (1024**3)
            
            # Determine performance tier
            gpu_lower = gpu_name.lower()
            if 'rtx 4090' in gpu_lower or 'rtx 4080' in gpu_lower:
                performance_tier = "Ultra"
            elif 'rtx 3090' in gpu_lower or 'rtx 3080' in gpu_lower:
                performance_tier = "Pro"
            elif 'rtx 4070' in gpu_lower or 'rtx 4060' in gpu_lower:
                performance_tier = "Pro"
            elif 'gtx' in gpu_lower or 'rtx' in gpu_lower:
                performance_tier = "Standard"
            else:
                performance_tier = "Legacy"
            
            return DeviceInfo(
                device_type="cuda",
                device_name=gpu_name,
                memory_gb=memory_gb,
                performance_tier=performance_tier,
                supported=True
            )
            
        except Exception as e:
            return DeviceInfo(
                device_type="cuda",
                device_name="NVIDIA CUDA",
                memory_gb=0,
                performance_tier="Error",
                supported=False,
                error_message=str(e)
            )
    
    def _detect_rocm_device(self) -> DeviceInfo:
        """Detect AMD ROCm capabilities"""
        try:
            if not hasattr(torch.backends, 'rocm') or not torch.backends.rocm.is_available():
                return DeviceInfo(
                    device_type="rocm",
                    device_name="AMD ROCm",
                    memory_gb=0,
                    performance_tier="Unsupported",
                    supported=False,
                    error_message="ROCm not available"
                )
            
            return DeviceInfo(
                device_type="rocm",
                device_name="AMD GPU (ROCm)",
                memory_gb=12,  # Estimate
                performance_tier="Standard",
                supported=True
            )
            
        except Exception as e:
            return DeviceInfo(
                device_type="rocm",
                device_name="AMD ROCm",
                memory_gb=0,
                performance_tier="Error",
                supported=False,
                error_message=str(e)
            )
    
    def _detect_cpu_device(self) -> DeviceInfo:
        """Detect CPU capabilities"""
        try:
            cpu_cores = self.system_info.cpu_cores
            memory_gb = self.system_info.total_memory_gb
            
            if cpu_cores >= 16:
                performance_tier = "Pro"
                recommended_memory = min(12, memory_gb * 0.6)
            elif cpu_cores >= 8:
                performance_tier = "Standard"
                recommended_memory = min(8, memory_gb * 0.5)
            else:
                performance_tier = "Legacy"
                recommended_memory = min(4, memory_gb * 0.4)
            
            return DeviceInfo(
                device_type="cpu",
                device_name=f"CPU ({cpu_cores} cores)",
                memory_gb=recommended_memory,
                performance_tier=performance_tier,
                supported=True
            )
            
        except Exception as e:
            return DeviceInfo(
                device_type="cpu",
                device_name="CPU",
                memory_gb=0,
                performance_tier="Error",
                supported=False,
                error_message=str(e)
            )
    
    def _select_best_device(self) -> str:
        """Select the best available device based on current resource state"""
        # Priority order: MPS > CUDA > ROCm > CPU
        priority_order = ['mps', 'cuda', 'rocm', 'cpu']
        
        # Get current resource state
        available_memory_gb = self.system_info.available_memory_gb
        total_memory_gb = self.system_info.total_memory_gb
        cpu_percent = self.system_info.cpu_percent
        
        # Calculate other processes memory usage
        other_processes_memory_gb = sum(p.memory_mb for p in self.other_processes) / 1024
        
        print(f"🔍 Dynamic Device Selection:")
        print(f"   Available Memory: {available_memory_gb:.1f}GB")
        print(f"   Total Memory: {total_memory_gb:.1f}GB")
        print(f"   CPU Usage: {cpu_percent:.1f}%")
        print(f"   Other Processes: {other_processes_memory_gb:.1f}GB")
        
        for device_type in priority_order:
            if device_type not in self.devices or not self.devices[device_type].supported:
                print(f"   ❌ {device_type.upper()}: Not supported")
                continue
            
            device = self.devices[device_type]
            print(f"   ✅ {device_type.upper()}: {device.device_name} ({device.performance_tier})")
            
            # For MPS, check if we have enough memory for safe operation
            if device_type == "mps":
                # MPS has memory limitations - check if we can safely use it
                available_percent = available_memory_gb / total_memory_gb
                
                if available_percent < 0.25:  # Less than 25% available
                    print(f"   ⚠️ MPS: Low memory ({available_percent:.1%} available) - skipping MPS")
                    continue
                elif available_percent < 0.4:  # Less than 40% available
                    print(f"   ⚠️ MPS: Medium memory ({available_percent:.1%} available) - using conservative MPS")
                    # Still use MPS but with very conservative settings
                    return device_type
                else:
                    print(f"   ✅ MPS: Good memory ({available_percent:.1%} available) - using optimal MPS")
                    return device_type
            
            # For other devices, check basic memory requirements
            elif device_type in ['cuda', 'rocm']:
                if available_memory_gb < 6.0:
                    print(f"   ⚠️ {device_type.upper()}: Insufficient memory ({available_memory_gb:.1f}GB < 6GB) - skipping")
                    continue
                else:
                    print(f"   ✅ {device_type.upper()}: Sufficient memory ({available_memory_gb:.1f}GB)")
                    return device_type
            
            # CPU is always available as fallback
            elif device_type == "cpu":
                print(f"   ✅ CPU: Always available as fallback")
                return device_type
        
        # If we get here, fall back to CPU
        print(f"   🔄 Falling back to CPU due to resource constraints")
        return 'cpu'  # Fallback
    
    def _detect_other_processes(self) -> List[ProcessInfo]:
        """Detect other resource-intensive processes"""
        processes = []
        
        gpu_intensive_keywords = [
            'chrome', 'safari', 'firefox', 'brave',
            'photoshop', 'illustrator', 'indesign',
            'final cut', 'premiere', 'after effects',
            'blender', 'maya', 'cinema 4d',
            'unity', 'unreal',
            'docker', 'vmware', 'parallels',
            'xcode', 'android studio',
            'zoom', 'teams', 'slack',
            'spotify', 'itunes',
            'steam', 'epic', 'origin'
        ]
        
        try:
            for proc in psutil.process_iter(['pid', 'name', 'memory_info', 'cpu_percent']):
                try:
                    proc_info = proc.info
                    proc_name = proc_info['name'].lower()
                    memory_mb = proc_info['memory_info'].rss / (1024**2) if proc_info['memory_info'] else 0
                    cpu_percent = proc_info['cpu_percent'] if proc_info['cpu_percent'] else 0
                    
                    is_gpu_intensive = any(keyword in proc_name for keyword in gpu_intensive_keywords)
                    
                    if (is_gpu_intensive and memory_mb > 100) or memory_mb > 500:
                        processes.append(ProcessInfo(
                            name=proc_info['name'],
                            memory_mb=memory_mb,
                            cpu_percent=cpu_percent,
                            is_gpu_intensive=is_gpu_intensive
                        ))
                        
                except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                    continue
            
            # Sort by memory usage
            processes.sort(key=lambda x: x.memory_mb, reverse=True)
            
        except Exception as e:
            print(f"⚠️ Could not detect processes: {e}")
        
        return processes[:10]  # Top 10
    
    def _calculate_resource_allocation(self) -> ResourceAllocation:
        """Calculate optimal resource allocation based on selected device"""
        best_device = self.devices[self.best_device]
        total_memory_gb = self.system_info.total_memory_gb
        available_memory_gb = self.system_info.available_memory_gb
        
        # Calculate other processes memory usage
        other_processes_memory_gb = sum(p.memory_mb for p in self.other_processes) / 1024
        
        print(f"📊 Resource Allocation for {self.best_device.upper()}:")
        print(f"   Total Memory: {total_memory_gb:.1f}GB")
        print(f"   Available Memory: {available_memory_gb:.1f}GB")
        print(f"   Other Processes: {other_processes_memory_gb:.1f}GB")
        
        # Base allocation strategy
        if self.best_device == "mps":
            # MPS-specific allocation with memory constraints
            available_percent = available_memory_gb / total_memory_gb
            
            if available_percent < 0.3:  # Less than 30% available
                print(f"   🟡 Conservative MPS: {available_percent:.1%} available")
                base_allocation_gb = min(2.0, available_memory_gb * 0.3)
            elif available_percent < 0.5:  # Less than 50% available
                print(f"   🟡 Moderate MPS: {available_percent:.1%} available")
                base_allocation_gb = min(4.0, available_memory_gb * 0.4)
            else:  # More than 50% available
                print(f"   🟢 Optimal MPS: {available_percent:.1%} available")
                base_allocation_gb = min(6.0, available_memory_gb * 0.5)
                
        elif self.best_device == "cpu":
            # CPU allocation - can use more memory since no GPU constraints
            print(f"   🟢 CPU Allocation: No GPU memory constraints")
            base_allocation_gb = min(8.0, available_memory_gb * 0.7)
            
        else:
            # CUDA/ROCm allocation
            print(f"   🟢 GPU Allocation: {self.best_device.upper()}")
            base_allocation_gb = min(12.0, available_memory_gb * 0.6)
        
        # Adjust for other processes and CPU load
        cpu_load_factor = 1.0 - (self.system_info.cpu_percent / 100.0)
        safe_allocation_gb = min(
            base_allocation_gb,
            available_memory_gb * 0.7,
            total_memory_gb - other_processes_memory_gb - (total_memory_gb * 0.2)
        )
        
        # Ensure minimum requirements
        final_allocation_gb = max(safe_allocation_gb, 2.0)  # Reduced minimum for better compatibility
        final_allocation_gb = min(final_allocation_gb, 16.0)  # Cap at 16GB
        
        print(f"   📈 Final Allocation: {final_allocation_gb:.1f}GB")
        
        # Calculate memory fraction dynamically
        memory_fraction = min(final_allocation_gb / total_memory_gb, 0.8)
        
        # Determine if conservative settings are needed based on system load
        # Modified for better performance - more lenient thresholds
        use_conservative = any([
            available_memory_gb < 2.0,  # Much more lenient threshold
            len([p for p in self.other_processes if p.is_gpu_intensive]) > 8,  # Much more lenient threshold
            self.system_info.cpu_percent > 95,  # Much more lenient threshold
            final_allocation_gb < 2.0,  # Much more lenient threshold
            self.best_device == "mps" and available_memory_gb < 3.0,  # Much more lenient MPS threshold
        ])
        
        # Adjust parameters based on conservative mode
        if use_conservative:
            batch_size = 2  # Increased from 1
            attention_heads = 24  # Increased from 16
            hidden_size = 3072  # Increased from 2048
            conservative_memory_gb = min(final_allocation_gb, 6.0)  # Increased from 4.0
            print(f"   ⚠️ Conservative Mode: Enabled (Optimized)")
        else:
            batch_size = 4  # Increased from 2
            attention_heads = 32
            hidden_size = 4096
            conservative_memory_gb = final_allocation_gb
            print(f"   ✅ Optimal Mode: Enabled")
        
        print(f"   📊 Settings: Batch={batch_size}, Heads={attention_heads}, Hidden={hidden_size}")
        
        return ResourceAllocation(
            recommended_memory_gb=final_allocation_gb,
            conservative_memory_gb=conservative_memory_gb,
            memory_fraction=memory_fraction,
            batch_size=batch_size,
            attention_heads=attention_heads,
            hidden_size=hidden_size,
            use_conservative=use_conservative,
            safety_margin_gb=total_memory_gb * 0.2
        )
    
    def test_memory_allocation(self) -> Dict[str, Any]:
        """Test memory allocation strategy"""
        print("🧪 Testing memory allocation...")
        
        test_results = {
            "success": True,
            "tests": []
        }
        
        # Test 1: Basic memory availability
        try:
            if self.system_info.available_memory_gb < 4.0:
                test_results["tests"].append({
                    "name": "Minimum Memory",
                    "status": "FAILED",
                    "message": f"Only {self.system_info.available_memory_gb:.1f}GB available, need at least 4GB"
                })
                test_results["success"] = False
            else:
                test_results["tests"].append({
                    "name": "Minimum Memory",
                    "status": "PASSED",
                    "message": f"Sufficient memory: {self.system_info.available_memory_gb:.1f}GB available"
                })
        except Exception as e:
            test_results["tests"].append({
                "name": "Minimum Memory",
                "status": "ERROR",
                "message": f"Test failed: {e}"
            })
            test_results["success"] = False
        
        # Test 2: Device compatibility
        try:
            if not self.devices[self.best_device].supported:
                test_results["tests"].append({
                    "name": "Device Compatibility",
                    "status": "FAILED",
                    "message": f"Best device {self.best_device} not supported: {self.devices[self.best_device].error_message}"
                })
                test_results["success"] = False
            else:
                test_results["tests"].append({
                    "name": "Device Compatibility",
                    "status": "PASSED",
                    "message": f"Device {self.best_device} ({self.devices[self.best_device].device_name}) supported"
                })
        except Exception as e:
            test_results["tests"].append({
                "name": "Device Compatibility",
                "status": "ERROR",
                "message": f"Test failed: {e}"
            })
            test_results["success"] = False
        
        # Test 3: Memory allocation strategy
        try:
            if self.resource_allocation.recommended_memory_gb < 4.0:
                test_results["tests"].append({
                    "name": "Memory Allocation",
                    "status": "WARNING",
                    "message": f"Low allocation: {self.resource_allocation.recommended_memory_gb:.1f}GB (conservative mode recommended)"
                })
            else:
                test_results["tests"].append({
                    "name": "Memory Allocation",
                    "status": "PASSED",
                    "message": f"Allocation: {self.resource_allocation.recommended_memory_gb:.1f}GB"
                })
        except Exception as e:
            test_results["tests"].append({
                "name": "Memory Allocation",
                "status": "ERROR",
                "message": f"Test failed: {e}"
            })
            test_results["success"] = False
        
        # Test 4: System load
        try:
            if self.system_info.cpu_percent > 80:
                test_results["tests"].append({
                    "name": "System Load",
                    "status": "WARNING",
                    "message": f"High CPU usage: {self.system_info.cpu_percent:.1f}%"
                })
            else:
                test_results["tests"].append({
                    "name": "System Load",
                    "status": "PASSED",
                    "message": f"CPU usage: {self.system_info.cpu_percent:.1f}%"
                })
        except Exception as e:
            test_results["tests"].append({
                "name": "System Load",
                "status": "ERROR",
                "message": f"Test failed: {e}"
            })
            test_results["success"] = False
        
        return test_results
    
    def generate_config(self) -> Dict[str, Any]:
        """Generate configuration for the main server"""
        return {
            "device": self.best_device,
            "device_info": asdict(self.devices[self.best_device]),
            "resource_allocation": asdict(self.resource_allocation),
            "system_info": asdict(self.system_info),
            "other_processes": [asdict(p) for p in self.other_processes[:5]],
            "recommendations": self._generate_recommendations()
        }
    
    def _generate_recommendations(self) -> List[str]:
        """Generate recommendations based on system analysis"""
        recommendations = []
        
        if self.resource_allocation.use_conservative:
            recommendations.append("Use conservative memory settings due to system load")
        
        if self.system_info.available_memory_gb < 8.0:
            recommendations.append("Close other applications to free up memory")
        
        if self.system_info.cpu_percent > 70:
            recommendations.append("System is under high load, consider reducing batch size")
        
        if len([p for p in self.other_processes if p.is_gpu_intensive]) > 3:
            recommendations.append("Many GPU-intensive applications running, consider closing some")
        
        if self.best_device == "cpu":
            recommendations.append("No GPU acceleration available, performance will be limited")
        
        if not recommendations:
            recommendations.append("System is well-optimized for model loading")
        
        return recommendations
    
    def print_detailed_report(self):
        """Print a detailed system analysis report"""
        print("=" * 80)
        print("🔍 DEVICE DETECTION AND RESOURCE VALIDATION REPORT")
        print("=" * 80)
        
        # System Information
        print(f"\n📊 SYSTEM INFORMATION:")
        print(f"   Platform: {self.system_info.platform}")
        print(f"   CPU Cores: {self.system_info.cpu_cores}")
        print(f"   Total Memory: {self.system_info.total_memory_gb:.1f}GB")
        print(f"   Available Memory: {self.system_info.available_memory_gb:.1f}GB")
        print(f"   CPU Usage: {self.system_info.cpu_percent:.1f}%")
        print(f"   Disk Free: {self.system_info.disk_free_gb:.1f}GB")
        
        # Device Information
        print(f"\n🎯 DEVICE DETECTION:")
        for device_type, device in self.devices.items():
            status = "✅" if device.supported else "❌"
            print(f"   {status} {device_type.upper()}: {device.device_name}")
            if device.supported:
                print(f"      Memory: {device.memory_gb:.1f}GB, Tier: {device.performance_tier}")
            else:
                print(f"      Error: {device.error_message}")
        
        print(f"\n🏆 SELECTED DEVICE: {self.best_device.upper()}")
        best_device_info = self.devices[self.best_device]
        print(f"   Name: {best_device_info.device_name}")
        print(f"   Performance Tier: {best_device_info.performance_tier}")
        print(f"   Memory: {best_device_info.memory_gb:.1f}GB")
        
        # Resource Allocation
        print(f"\n🧠 RESOURCE ALLOCATION:")
        print(f"   Recommended Memory: {self.resource_allocation.recommended_memory_gb:.1f}GB")
        print(f"   Conservative Memory: {self.resource_allocation.conservative_memory_gb:.1f}GB")
        print(f"   Memory Fraction: {self.resource_allocation.memory_fraction:.1%}")
        print(f"   Batch Size: {self.resource_allocation.batch_size}")
        print(f"   Attention Heads: {self.resource_allocation.attention_heads}")
        print(f"   Hidden Size: {self.resource_allocation.hidden_size}")
        print(f"   Conservative Mode: {self.resource_allocation.use_conservative}")
        
        # Other Processes
        if self.other_processes:
            print(f"\n🔄 OTHER PROCESSES (Top 5):")
            for i, proc in enumerate(self.other_processes[:5]):
                gpu_marker = "🎮" if proc.is_gpu_intensive else "📱"
                print(f"   {i+1}. {gpu_marker} {proc.name}: {proc.memory_mb:.0f}MB, CPU: {proc.cpu_percent:.1f}%")
        
        # Test Results
        test_results = self.test_memory_allocation()
        print(f"\n🧪 VALIDATION TESTS:")
        for test in test_results["tests"]:
            status_icon = {"PASSED": "✅", "FAILED": "❌", "WARNING": "⚠️", "ERROR": "💥"}[test["status"]]
            print(f"   {status_icon} {test['name']}: {test['message']}")
        
        # Recommendations
        recommendations = self._generate_recommendations()
        print(f"\n💡 RECOMMENDATIONS:")
        for rec in recommendations:
            print(f"   • {rec}")
        
        # Configuration
        config = self.generate_config()
        print(f"\n⚙️ GENERATED CONFIGURATION:")
        print(f"   Device: {config['device']}")
        print(f"   Memory Allocation: {config['resource_allocation']['recommended_memory_gb']:.1f}GB")
        print(f"   Conservative Mode: {config['resource_allocation']['use_conservative']}")
        
        print("\n" + "=" * 80)
        
        return test_results["success"]

def main():
    """Main function to run device detection and validation"""
    print("🚀 Starting Device Detection and Resource Validation...")
    
    try:
        # Initialize detector
        detector = DeviceDetector()
        
        # Print detailed report
        success = detector.print_detailed_report()
        
        # Generate configuration
        config = detector.generate_config()
        
        # Save configuration to file
        config_file = "device_config.json"
        with open(config_file, 'w') as f:
            json.dump(config, f, indent=2)
        
        print(f"\n💾 Configuration saved to: {config_file}")
        
        if success:
            print("\n✅ System validation PASSED - Ready for model loading!")
            print("\n📋 Next Steps:")
            print("   1. Review the configuration above")
            print("   2. Address any warnings or recommendations")
            print("   3. Run the main server: python optimized_resource_server.py")
            return 0
        else:
            print("\n❌ System validation FAILED - Please address issues before loading model")
            return 1
            
    except Exception as e:
        print(f"\n💥 Device detection failed: {e}")
        return 1

if __name__ == "__main__":
    exit(main()) 