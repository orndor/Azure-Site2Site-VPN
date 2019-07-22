# 1. Define common network parameters
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

# 2. Create a resource group
New-AzResourceGroup -ResourceGroupName $RG1 -Location $Location1

# 3. Create a virtual network
$fesub1 = New-AzVirtualNetworkSubnetConfig -Name $FESubnet1 -AddressPrefix $FEPrefix1
$besub1 = New-AzVirtualNetworkSubnetConfig -Name $BESubnet1 -AddressPrefix $BEPrefix1
$gwsub1 = New-AzVirtualNetworkSubnetConfig -Name $GWSubnet1 -AddressPrefix $GwPrefix1
$vnet   = New-AzVirtualNetwork `
            -Name $VNet1 `
            -ResourceGroupName $RG1 `
            -Location $Location1 `
            -AddressPrefix $VNet1Prefix `
            -Subnet $fesub1,$besub1,$gwsub1

# 4. Request a public IP address for the VPN gateway (this will be a dynamic IP)
$gwpip    = New-AzPublicIpAddress -Name $GwIP1 -ResourceGroupName $RG1 `
            -Location $Location1 -AllocationMethod Dynamic
$subnet   = Get-AzVirtualNetworkSubnetConfig -Name 'GatewaySubnet' `
            -VirtualNetwork $vnet
$gwipconf = New-AzVirtualNetworkGatewayIpConfig -Name $GwIPConf1 `
            -Subnet $subnet -PublicIpAddress $gwpip

# 5. Create a VPN gateway (this will take up to 45 minutes)
New-AzVirtualNetworkGateway -Name $Gw1 -ResourceGroupName $RG1 `
-Location $Location1 -IpConfigurations $gwipconf -GatewayType Vpn `
-VpnType RouteBased -GatewaySku VpnGw1

# 6. Create a local network gateway
New-AzLocalNetworkGateway -Name $LNG1 -ResourceGroupName $RG1 `
-Location 'East US' -GatewayIpAddress $LNGIP1 -AddressPrefix $LNGprefix1,$LNGprefix2

# 7. Create a S2S VPN connection
$vng1 = Get-AzVirtualNetworkGateway -Name $GW1  -ResourceGroupName $RG1
$lng1 = Get-AzLocalNetworkGateway   -Name $LNG1 -ResourceGroupName $RG1

New-AzVirtualNetworkGatewayConnection -Name $Connection1 -ResourceGroupName $RG1 `
-Location $Location1 -VirtualNetworkGateway1 $vng1 -LocalNetworkGateway2 $lng1 `
-ConnectionType IPsec -SharedKey "Azure@!b2C3"

# 8. Enable BGP on the VPN connection

$vng1 = Get-AzVirtualNetworkGateway -Name $GW1  -ResourceGroupName $RG1
Set-AzVirtualNetworkGateway -VirtualNetworkGateway $vng1 -Asn $VNet1ASN

$lng1 = Get-AzLocalNetworkGateway -Name $LNG1 -ResourceGroupName $RG1
Set-AzLocalNetworkGateway -LocalNetworkGateway $lng1 `
-Asn $LNGASN1 -BgpPeeringAddress $BGPPeerIP1

$connection = Get-AzVirtualNetworkGatewayConnection `
-Name $Connection1 -ResourceGroupName $RG1

Set-AzVirtualNetworkGatewayConnection -VirtualNetworkGatewayConnection $connection `
-EnableBGP $True
