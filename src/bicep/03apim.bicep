/*
------------------------
parameters
------------------------
*/
param environment_shortname string
param prefix string
param app_suffix string 
param uamsi string
param apim_subnet_id string
param workspace_id string

// default parameters
param apim_sku string = 'Developer'
param apim_capacity int = 1
param internal_domain string = 'demo.internal'
param apim_gatewayhostname string = 'api.${internal_domain}'
param apim_portalhostname string = 'portal.${internal_domain}'
param apim_mgmthostname string = 'mgmt.${internal_domain}'
param keyvault_gw_cert string = 'domain-internal'
param keyvault_mgmt_cert string = 'domain-internal'
param keyvault_portal_cert string = 'domain-internal'
param tags object = {
  env: environment_shortname
  costCenter: '1234'
}

/*
------------------------
global variables
------------------------
*/
var suffix = '${environment_shortname}-${app_suffix}'
var keyvault_name = '${prefix}-key-${environment_shortname}-${app_suffix}'
var vnet_name = '${prefix}-net-${environment_shortname}-${app_suffix}'
var msi_name = '${prefix}-msi-${environment_shortname}-${app_suffix}'

/*
------------------------
external references
------------------------
*/
resource existing_keyvault 'Microsoft.KeyVault/vaults@2020-04-01-preview' existing = {
  name : keyvault_name
}

resource existing_identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name : msi_name
}

/*
------------------------
resources
------------------------
*/
var apim_service_name = '${prefix}-apm-${suffix}'
var apim_publisher_email = 'jeroen.maes@cegeka.com'


resource apim 'Microsoft.ApiManagement/service@2021-01-01-preview' = {
  name: apim_service_name
  location: resourceGroup().location
  tags: tags
  sku:{
    name: apim_sku
    capacity : apim_capacity
  }
  properties:{
    publisherEmail : apim_publisher_email
    publisherName : 'Codit'
    virtualNetworkConfiguration:{
      subnetResourceId: apim_subnet_id
    }
    hostnameConfigurations:[
      {  
        type:'Proxy'
        hostName: apim_gatewayhostname
        keyVaultId: 'https://${existing_keyvault.name}.vault.azure.net/secrets/${keyvault_gw_cert}'
        identityClientId : uamsi
        negotiateClientCertificate:false
        defaultSslBinding: true
      }
      {  
        type:'DeveloperPortal'
        hostName: apim_portalhostname
        keyVaultId: 'https://${existing_keyvault.name}.vault.azure.net/secrets/${keyvault_portal_cert}'
        identityClientId : uamsi
        negotiateClientCertificate:false
        defaultSslBinding: false
      }  
      {  
        type: 'Management'
        hostName: apim_mgmthostname
        keyVaultId: 'https://${existing_keyvault.name}.vault.azure.net/secrets/${keyvault_mgmt_cert}'
        identityClientId : uamsi
        negotiateClientCertificate:false
        defaultSslBinding: false
      } 
    ] 
   customProperties:{
    'Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2': 'True'
   }
   virtualNetworkType: 'Internal'
  }
  identity:{
    type:'UserAssigned'
    userAssignedIdentities:{
      '${existing_identity.id}' : {}
    }
  }
}

resource diagSettings 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'writeToLogAnalytics'
  scope: apim
  properties:{
   logAnalyticsDestinationType: 'Dedicated'
   workspaceId : workspace_id
    logs:[
      {
        category: 'GatewayLogs'
        enabled:true
        retentionPolicy:{
          enabled:false
          days: 0
        }
      }         
    ]
    metrics:[
      {
        category: 'AllMetrics'
        enabled:true
        timeGrain: 'PT1M'
        retentionPolicy:{
         enabled:false
         days: 0
       }
      }
    ]
  }
 }

/*
------------------------
outputs
------------------------
*/
output apimRespourceId string = apim.id
