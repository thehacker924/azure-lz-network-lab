using './network.bicep'

param workloadsResourceGroup = 'rg-lz-workloads'

param tags = {
  project: 'azure-lz-network-lab'
  environment: 'lab'
  managedBy: 'bicep'
  costCenter: 'lab-demo'
}

// 10.100.0.0/26 and 10.100.0.64/26 are reserved for the firewall subnets (Phase 7).
param hub = {
  name: 'vnet-lz-hub'
  addressPrefix: '10.100.0.0/22'
  subnets: [
    {
      name: 'snet-shared'
      addressPrefix: '10.100.1.0/24'
    }
  ]
}

param spokes = [
  {
    name: 'vnet-lz-spoke1'
    addressPrefix: '10.101.0.0/22'
    subnets: [
      {
        name: 'snet-web'
        addressPrefix: '10.101.0.0/24'
      }
      {
        name: 'snet-app'
        addressPrefix: '10.101.1.0/24'
      }
    ]
  }
  {
    name: 'vnet-lz-spoke2'
    addressPrefix: '10.102.0.0/22'
    subnets: [
      {
        name: 'snet-data'
        addressPrefix: '10.102.0.0/24'
      }
    ]
  }
]
