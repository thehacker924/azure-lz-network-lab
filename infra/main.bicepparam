using './main.bicep'

param location = 'eastus2'
param prefix = 'lz'
param tags = {
  project: 'azure-lz-network-lab'
  environment: 'lab'
  managedBy: 'bicep'
  costCenter: 'lab-demo'
}
