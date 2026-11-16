// One virtual network with inline subnets (so a redeploy never deletes them).
@description('Name of the virtual network.')
param name string

@description('Region for the virtual network.')
param location string

@description('Tags for the virtual network.')
param tags object

@description('Address space, for example 10.101.0.0/22.')
param addressPrefix string

@description('Subnets: each item has name, addressPrefix and nsg (empty string for none).')
param subnets array

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [for subnet in subnets: {
      name: subnet.name
      properties: union(
        {
          addressPrefix: subnet.addressPrefix
          // Private subnet: no hidden internet access for VMs.
          defaultOutboundAccess: false
        },
        empty(subnet.nsg) ? {} : {
          networkSecurityGroup: {
            id: resourceId('Microsoft.Network/networkSecurityGroups', subnet.nsg)
          }
        }
      )
    }]
  }
}

output id string = vnet.id
output name string = vnet.name
