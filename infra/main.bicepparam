using './main.bicep'

param prefix = 'taskflow'
param aksNodeCount = 2
// Supplied at deploy time:  az deployment group create ... -p postgresAdminPassword=<value>
param postgresAdminPassword = readEnvironmentVariable('POSTGRES_ADMIN_PASSWORD', '')
