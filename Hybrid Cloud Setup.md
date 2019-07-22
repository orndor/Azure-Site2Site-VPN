# Steps to setup Hybrid Cloud with GNS3

1. Install Azure PowerShell module. [Instructions](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-2.4.0)

    ```powershell
    Install-Module -Name Az -AllowClobber -Scope CurrentUser
    ```

2. Connect to Azure Account (the integration with windows is nice):

    ```powershell
    Connect-AzAccount
    ```

3. Define common network parameters

    ```powershell
    # Virtual network
    $RG1         = "TestRG1"
    $VNet1       = "VNet1"
    $Location1   = "East US"
    $VNet1Prefix = "10.1.0.0/16"
    $VNet1ASN    = 65010
    $GW1         = "VNet1GW"
    $FESubnet1   = "FrontEnd"
    $BESubnet1   = "Backend"
    $GwSubnet1   = "GatewaySubnet"
    $FEPrefix1   = "10.1.0.0/24"
    $BEPrefix1   = "10.1.1.0/24"
    $GwPrefix1   = "10.1.255.0/27"
    $DNS1        = "8.8.8.8"
    $GwIP1       = "VNet1GWIP"
    $GwIPConf1   = "gwipconf1"
    # On-premises network - LNGIP1 is the VPN device public IP address
    $LNG1        = "VPNsite1"
    $LNGprefix1  = "10.101.0.0/24"
    $LNGprefix2  = "10.101.1.0/24"
    $LNGIP1      = "65.191.34.34"
    # On-premises BGP properties
    $LNGASN1     = 65011
    $BGPPeerIP1  = "10.101.1.254"
    # Connection
    $Connection1 = "VNet1ToSite1"
    ```

4. Create a resource group

    ```powershell
    New-AzResourceGroup -ResourceGroupName $RG1 -Location $Location1
    ```

5. Create a virtual network

    ```powershell
    $fesub1 = New-AzVirtualNetworkSubnetConfig -Name $FESubnet1 -AddressPrefix $FEPrefix1
    $besub1 = New-AzVirtualNetworkSubnetConfig -Name $BESubnet1 -AddressPrefix $BEPrefix1
    $gwsub1 = New-AzVirtualNetworkSubnetConfig -Name $GWSubnet1 -AddressPrefix $GwPrefix1
    $vnet   = New-AzVirtualNetwork `
                -Name $VNet1 `
                -ResourceGroupName $RG1 `
                -Location $Location1 `
                -AddressPrefix $VNet1Prefix `
                -Subnet $fesub1,$besub1,$gwsub1
    ```

6. Request a public IP address for the VPN gateway (this will be a dynamic IP)

    ```powershell
    $gwpip    = New-AzPublicIpAddress -Name $GwIP1 -ResourceGroupName $RG1 `
                -Location $Location1 -AllocationMethod Dynamic
    $subnet   = Get-AzVirtualNetworkSubnetConfig -Name 'GatewaySubnet' `
                -VirtualNetwork $vnet
    $gwipconf = New-AzVirtualNetworkGatewayIpConfig -Name $GwIPConf1 `
                -Subnet $subnet -PublicIpAddress $gwpip
    ```

7. Create a VPN gateway (this will take up to 45 minutes)

    ```powershell
    New-AzVirtualNetworkGateway -Name $Gw1 -ResourceGroupName $RG1 `
    -Location $Location1 -IpConfigurations $gwipconf -GatewayType Vpn `
    -VpnType RouteBased -GatewaySku VpnGw1 -EnableBgp $True -Asn $VNet1ASN
    ```

8. Create a local network gateway

    ```powershell
    New-AzLocalNetworkGateway -Name $LNG1 -ResourceGroupName $RG1 `
    -Location 'East US' -GatewayIpAddress $LNGIP1 -AddressPrefix $LNGprefix1,$LNGprefix2
    ```

9. Create a S2S VPN connection with BGP Enabled

    ```powershell
    $vng1 = Get-AzVirtualNetworkGateway -Name $GW1  -ResourceGroupName $RG1
    $lng1 = Get-AzLocalNetworkGateway   -Name $LNG1 -ResourceGroupName $RG1

    New-AzVirtualNetworkGatewayConnection -Name $Connection1 -ResourceGroupName $RG1 `
    -Location $Location1 -VirtualNetworkGateway1 $vng1 -LocalNetworkGateway2 $lng1 `
    -ConnectionType IPsec -SharedKey "Azure@!b2C3" -EnableBGP $True
    ```

10. Download Premise equipment sample configs.  Got to [this site.](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-download-vpndevicescript)

## Verification and Troubleshooting commands for the CLI

* View the gateway public IP address

    ```powershell
    $myGwIp = Get-AzPublicIpAddress -Name $GwIP1 -ResourceGroup $RG1
    $myGwIp.IpAddress
    ```

* Resize a gateway

    ```powershell
    $gateway = Get-AzVirtualNetworkGateway -Name $Gw1 -ResourceGroup $RG1
    Resize-AzVirtualNetworkGateway -GatewaySku VpnGw2 -VirtualNetworkGateway $gateway
    ```

* Reset a gateway (for troubleshooting)

    ```powershell
    $gateway = Get-AzVirtualNetworkGateway -Name $Gw1 -ResourceGroup $RG1
    Reset-AzVirtualNetworkGateway -VirtualNetworkGateway $gateway
    ```

## Removal and Clean-Up

* Delete a Site-to-Site VPN connection

    ```powershell
    Remove-AzVirtualNetworkGatewayConnection -Name $Connection1 -ResourceGroupName $RG1

    Remove-AzVirtualNetworkGatewayConnection -Name $LNG1 -ResourceGroupName $RG1
    ```

* Clean up resources (this deletes everything)

    ```powershell
    Remove-AzResourceGroup -Name $RG1
    ```
