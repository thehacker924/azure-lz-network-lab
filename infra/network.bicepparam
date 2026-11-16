using './network.bicep'

param workloadsResourceGroup = 'rg-lz-workloads'

param tags = {
  project: 'azure-lz-network-lab'
  environment: 'lab'
  managedBy: 'bicep'
  costCenter: 'lab-demo'
}

param asgNames = [
  'asg-lz-web'
  'asg-lz-app'
  'asg-lz-data'
]

// 10.100.0.0/26 and 10.100.0.64/26 are reserved for the firewall subnets (Phase 7).
// snet-shared gets its NSG in Phase 7.
param hub = {
  name: 'vnet-lz-hub'
  addressPrefix: '10.100.0.0/22'
  subnets: [
    {
      name: 'snet-shared'
      addressPrefix: '10.100.1.0/24'
      nsg: ''
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
        nsg: 'nsg-lz-spoke1-web'
      }
      {
        name: 'snet-app'
        addressPrefix: '10.101.1.0/24'
        nsg: 'nsg-lz-spoke1-app'
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
        nsg: 'nsg-lz-spoke2-data'
      }
    ]
  }
]
