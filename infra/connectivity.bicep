// Hub network for rg-lz-connectivity. Phase 2 adds the resources.
targetScope = 'resourceGroup'

@description('Region for every resource. Defaults to the resource group region.')
param location string = resourceGroup().location

output deployedRegion string = location
