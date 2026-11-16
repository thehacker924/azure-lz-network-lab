// Application security groups. VMs join them in Phase 5.
@description('Names of the ASGs to create.')
param names array

@description('Region for the ASGs.')
param location string

@description('Tags for the ASGs.')
param tags object

resource asg 'Microsoft.Network/applicationSecurityGroups@2024-05-01' = [for name in names: {
  name: name
  location: location
  tags: tags
}]
