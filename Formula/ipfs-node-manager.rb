class IpfsNodeManager < Formula
  desc "Easy IPFS node setup and management tool"
  homepage "https://github.com/perceptivefocus/ipfs-node-manager"
  url "https://github.com/perceptivefocus/ipfs-node-manager/archive/v1.0.0.tar.gz"
  sha256 "REPLACE_WITH_ACTUAL_SHA256_AFTER_RELEASE"
  license "MIT"
  
  depends_on "ipfs"
  
  def install
    # Install the setup script to bin
    bin.install "scripts/setup-ipfs-node.sh" => "ipfs-setup"
    
    # Make directories for the helper script
    (prefix/"scripts").mkpath
    (prefix/"api").mkpath
    
    # Install API components if user wants to run the management API
    (prefix/"api").install Dir["api/*"]
    
    # Install the API startup script
    (prefix/"scripts").install "install.sh" => "ipfs-manager-install"
    
    # Make the scripts executable
    system "chmod", "+x", "#{bin}/ipfs-setup"
    system "chmod", "+x", "#{prefix}/scripts/ipfs-manager-install"
  end

  def caveats
    <<~EOS
      IPFS Node Manager
      --------------------------
      
      To set up a basic IPFS node, run:
        ipfs-setup
      
      To install and run the IPFS Node Manager API (optional):
        cd #{prefix}
        ./scripts/ipfs-manager-install
        cd ./api
        ./start.sh
      
      The API will be available at http://localhost:8000
    EOS
  end

  test do
    system "#{bin}/ipfs-setup", "--help"
  end
end 