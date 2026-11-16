// One NSG built from a network-policy JSON file.
// ASGs are looked up in this resource group.
@description('Parsed contents of one network-policy file.')
param policy object

@description('Region for the NSG.')
param location string

@description('Tags for the NSG.')
param tags object

// Ports: one value uses destinationPortRange, several use destinationPortRanges.
var portParts = [for rule in policy.rules: length(rule.ports) == 1 ? { destinationPortRange: rule.ports[0] } : { destinationPortRanges: rule.ports }]

// Source and destination: an ASG name wins over an address prefix or service tag.
var sourceParts = [for rule in policy.rules: empty(rule.sourceAsg) ? { sourceAddressPrefix: rule.source } : { sourceApplicationSecurityGroups: [ { id: resourceId('Microsoft.Network/applicationSecurityGroups', rule.sourceAsg) } ] }]
var destinationParts = [for rule in policy.rules: empty(rule.destinationAsg) ? { destinationAddressPrefix: rule.destination } : { destinationApplicationSecurityGroups: [ { id: resourceId('Microsoft.Network/applicationSecurityGroups', rule.destinationAsg) } ] }]

var securityRules = [for (rule, i) in policy.rules: {
  name: rule.name
  properties: union({ description: rule.description, priority: rule.priority, direction: rule.direction, access: rule.access, protocol: rule.protocol, sourcePortRange: '*' }, portParts[i], sourceParts[i], destinationParts[i])
}]

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: policy.nsgName
  location: location
  tags: union(tags, { purpose: policy.description })
  properties: {
    securityRules: securityRules
  }
}

output id string = nsg.id
