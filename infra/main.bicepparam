using './main.bicep'

param prefix = 'taskflow'
param aksNodeCount = 2
// Many new subscriptions can't create standard VM sizes in Southeast Asia; Central India works.
param location = 'centralindia'
param aksNodeVmSize = 'Standard_D2as_v5'
// PostgreSQL Burstable B1ms is blocked in Central India for this subscription; Southeast Asia works.
param postgresLocation = 'southeastasia'
// Supplied at deploy time:  az deployment group create ... -p postgresAdminPassword=<value>
param postgresAdminPassword = readEnvironmentVariable('POSTGRES_ADMIN_PASSWORD', '')
