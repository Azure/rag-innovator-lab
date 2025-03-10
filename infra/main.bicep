targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

// @description('current user objectId.')
// var currentUserObjectId string = deployer.objectId

@minLength(1)
@description('Primary location for all resources')
@allowed(['eastus', 'westus2', 'westeurope'])
@metadata({
  azd: {
    type: 'location'
  }
})
param location string

param resourceGroupName string = '' // Set in main.parameters.json

@secure()
param openAiServiceName string = ''

param useGPT4V bool = true

@description('Location for the OpenAI resource group')
@allowed([
  'eastus'
  'eastus2'
  'westus'
])
@metadata({
  azd: {
    type: 'location'
  }
})
param openAiResourceGroupLocation string

param azureOpenAiSkuName string = '' // Set in main.parameters.json

param documentIntelligenceServiceName string = '' // Set in main.parameters.json

param applicationInsightsName string = '' // Set in main.parameters.json
param logAnalyticsName string = '' // Set in main.parameters.json

param storageAccountName string = '' // Set in main.parameters.json
param storageSkuName string // Set in main.parameters.json

param keyVaultName string = '' // Set in main.parameters.json

param documentIntelligenceSkuName string // Set in main.parameters.json

param azureOpenAiDeploymentName string = '' // Set in main.parameters.json
param azureOpenAiDeploymentSkuName string = '' // Set in main.parameters.json
param azureOpenAiDeploymentVersion string = '' // Set in main.parameters.json
param azureOpenAiDeploymentCapacity int = 0 // Set in main.parameters.json
var gpt4omini = {
  modelName: 'gpt-4o-mini'
  deploymentName: !empty(azureOpenAiDeploymentName) ? azureOpenAiDeploymentName : 'gpt-4o-mini'
  deploymentVersion: !empty(azureOpenAiDeploymentVersion) ? azureOpenAiDeploymentVersion : '2024-07-18'
  deploymentSkuName: !empty(azureOpenAiDeploymentSkuName) ? azureOpenAiDeploymentSkuName : 'Standard'
  deploymentCapacity: azureOpenAiDeploymentCapacity != 0 ? azureOpenAiDeploymentCapacity : 30
}

param embeddingModelName string = ''
param embeddingDeploymentName string = ''
param embeddingDeploymentVersion string = ''
param embeddingDeploymentSkuName string = ''
param embeddingDeploymentCapacity int = 0
param embeddingDimensions int = 0
var embedding = {
  modelName: !empty(embeddingModelName) ? embeddingModelName : 'text-embedding-3-small'
  deploymentName: !empty(embeddingDeploymentName) ? embeddingDeploymentName : 'embedding'
  deploymentVersion: !empty(embeddingDeploymentVersion) ? embeddingDeploymentVersion : '1'
  deploymentSkuName: !empty(embeddingDeploymentSkuName) ? embeddingDeploymentSkuName : 'Standard'
  deploymentCapacity: embeddingDeploymentCapacity != 0 ? embeddingDeploymentCapacity : 30
  dimensions: embeddingDimensions != 0 ? embeddingDimensions : 1536
}

param gpt4vModelName string = ''
param gpt4vDeploymentName string = ''
param gpt4vModelVersion string = ''
param gpt4vDeploymentSkuName string = ''
param gpt4vDeploymentCapacity int = 0
var gpt4v = {
  modelName: !empty(gpt4vModelName) ? gpt4vModelName : 'gpt-4o'
  deploymentName: !empty(gpt4vDeploymentName) ? gpt4vDeploymentName : 'gpt-4o'
  deploymentVersion: !empty(gpt4vModelVersion) ? gpt4vModelVersion : '2024-05-13'
  deploymentSkuName: !empty(gpt4vDeploymentSkuName) ? gpt4vDeploymentSkuName : 'Standard'
  deploymentCapacity: gpt4vDeploymentCapacity != 0 ? gpt4vDeploymentCapacity : 30
}

//param tenantId string = tenant().tenantId

@allowed(['None', 'AzureServices'])
@description('If allowedIp is set, whether azure services are allowed to bypass the storage and AI services firewall.')
param bypass string = 'AzureServices'

@description('Public network access value for all deployed resources')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Enabled'

param guidValue string = newGuid()

var resourceToken = toLower(uniqueString(guidValue))

var abbrs = loadJsonContent('abbreviations.json')
var tags = { 'azd-env-name': environmentName }
var principalId = deployer().objectId

// Organize resources in a resource group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

var defaultOpenAiDeployments = [
  {
    name: gpt4omini.deploymentName
    model: {
      format: 'OpenAI'
      name: gpt4omini.modelName
      version: gpt4omini.deploymentVersion
    }
    sku: {
      name: gpt4omini.deploymentSkuName
      capacity: gpt4omini.deploymentCapacity
    }
  }
  {
    name: gpt4v.deploymentName
    model: {
      format: 'OpenAI'
      name: gpt4v.modelName
      version: gpt4v.deploymentVersion
    }
    sku: {
      name: gpt4v.deploymentSkuName
      capacity: gpt4v.deploymentCapacity
    }
  }
  {
    name: embedding.deploymentName
    model: {
      format: 'OpenAI'
      name: embedding.modelName
      version: embedding.deploymentVersion
    }
    sku: {
      name: embedding.deploymentSkuName
      capacity: embedding.deploymentCapacity
    }
  }
]

var openAiDeployments = concat(
  defaultOpenAiDeployments,
  useGPT4V
    ? [
        {
          name: gpt4v.deploymentName
          model: {
            format: 'OpenAI'
            name: gpt4v.modelName
            version: gpt4v.deploymentVersion
          }
          sku: {
            name: gpt4v.deploymentSkuName
            capacity: gpt4v.deploymentCapacity
          }
        }
      ]
    : []
)

module vault 'br/public:avm/res/key-vault/vault:0.10.1' = {
  name: 'keyvault'
  scope: resourceGroup
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${resourceToken}'
    tags: tags
    enableRbacAuthorization: true
    roleAssignments: [
      {
        roleDefinitionIdOrName: '00482a5a-887f-4fb3-b363-3b7fe8e74483'
        principalId: principalId
        principalType: 'User'
      }
    ]
    location: location
    enableSoftDelete: false
    enablePurgeProtection: false
    networkAcls: {
      bypass: bypass
      defaultAction: 'Allow'
    }
  }
}

module openAi 'br/public:avm/res/cognitive-services/account:0.9.2' = {
  name: 'openai'
  scope: resourceGroup
  params: {
    name: '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    location: openAiResourceGroupLocation
    tags: tags
    kind: 'OpenAI'
    customSubDomainName: !empty(openAiServiceName)
      ? openAiServiceName
      : '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: 'Allow'
      bypass: bypass
    }
    sku: azureOpenAiSkuName
    deployments: openAiDeployments
    disableLocalAuth: false
    managedIdentities: {
      systemAssigned: true
    }
    secretsExportConfiguration: {
      accessKey1Name: 'openai-api-key1'
      accessKey2Name: 'openai-api-key2'
      keyVaultResourceId: vault.outputs.resourceId
    }
  }
}

module storageAccount 'br/public:avm/res/storage/storage-account:0.14.1' = {
  name: 'storage'
  scope: resourceGroup
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    kind: 'StorageV2'
    publicNetworkAccess: publicNetworkAccess
    roleAssignments: [
      {
        roleDefinitionIdOrName: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
        principalId: principalId
        principalType: 'User'
      }
    ]
    allowBlobPublicAccess: true
    allowSharedKeyAccess: true
    location: location
    tags: tags
    skuName: storageSkuName
    networkAcls: {
      bypass: bypass
      defaultAction: 'Allow'
    }
  }
}

module workspace 'br/public:avm/res/operational-insights/workspace:0.7.0' = {
  name: 'loganalytics'
  scope: resourceGroup
  params: {
    name: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.logAnayticsWorkspace}${resourceToken}'
    location: location
    tags: tags
    publicNetworkAccessForIngestion: publicNetworkAccess
  }
}

module appinsights 'br/public:avm/res/insights/component:0.4.1' = {
  name: 'appinsights'
  scope: resourceGroup
  params: {
    name: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    workspaceResourceId: workspace.outputs.resourceId
    location: location
    tags: tags
    publicNetworkAccessForIngestion: publicNetworkAccess
  }
}

// Does not support bypass
module documentIntelligence 'br/public:avm/res/cognitive-services/account:0.9.2' = {
  name: 'documentintelligence'
  scope: resourceGroup
  params: {
    name: '${abbrs.cognitiveServicesDocumentIntelligence}${resourceToken}'
    kind: 'FormRecognizer'
    customSubDomainName: !empty(documentIntelligenceServiceName)
      ? documentIntelligenceServiceName
      : '${abbrs.cognitiveServicesDocumentIntelligence}${resourceToken}'
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: 'Allow'
    }
    location: location
    disableLocalAuth: false
    tags: tags
    sku: documentIntelligenceSkuName
    secretsExportConfiguration: {
      accessKey1Name: 'documentIntelligence-api-key1'
      accessKey2Name: 'documentIntelligence-api-key2'
      keyVaultResourceId: vault.outputs.resourceId
    }
  }
}

module searchService 'br/public:avm/res/search/search-service:0.9.1' = {
  name: '${abbrs.cognitiveServicesSearch}${resourceToken}'
  scope: resourceGroup
  params: {
    name: '${abbrs.cognitiveServicesSearch}${resourceToken}'
    location: location
    disableLocalAuth: false
    tags: tags
    secretsExportConfiguration: {
      accessKey1Name: 'aisearch-api-key1'
      accessKey2Name: 'aisearch-api-key2'
      keyVaultResourceId: vault.outputs.resourceId
    }
  }
}

// Output for the labs
output AZURE_OPENAI_ENDPOINT string = openAi.outputs.endpoint
output AZURE_OPENAI_API_KEY object = openAi.outputs.exportedSecrets
output AZURE_OPENAI_API_VERSION string = azureOpenAiDeploymentVersion
output AZURE_OPENAI_DEPLOYMENT_NAME string = gpt4omini.deploymentName
output AZURE_OPENAI_EMB_MODEL_NAME string = embedding.modelName
output AZURE_DOC_INTELLIGENCE_ENDPOINT string = documentIntelligence.outputs.endpoint
output AZURE_DOC_INTELLIGENCE_KEY object = documentIntelligence.outputs.exportedSecrets
output AZURE_SEARCH_SERVICE_NAME string = searchService.outputs.name
output AZURE_SEARCH_SERVICE_KEY object = searchService.outputs.exportedSecrets
output AZURE_KEYVAULT_NAME string = vault.outputs.name

output AZURE_LOCATION string = location
// output AZURE_TENANT_ID string = tenantId
// output AZURE_RESOURCE_GROUP string = resourceGroup.name
//
// // Shared by all OpenAI deployments
//
// output AZURE_OPENAI_OPENAI_MODEL string = gpt4omini.modelName
// output AZURE_OPENAI_GPT4V_MODEL string = gpt4v.modelName
//
// // Specific to Azure OpenAI
// output AZURE_OPENAI_SERVICE_NAME string = openAi.outputs.name
//
// output AZURE_OPENAI_EMB_DEPLOYMENT_NAME string = embedding.deploymentName
// output AZURE_OPENAI_GPT4V_DEPLOYMENT_NAME string = gpt4v.deploymentName
// output AZURE_DOCUMENTINTELLIGENCE_SERVICE string = documentIntelligence.outputs.name
//