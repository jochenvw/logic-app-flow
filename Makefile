# Please fill out the following:
sqlAADAdminUsername="[AzureAD-username]"
sqlAADAdminObjectId="[AzureAD-user-objectid]"

# Application runs in 2 resource groups
# - 'flow-core-services-rg' 	- contains core services like logic-app, log analytics etc.
# - 'flow-managed-services-rg' 	- the resource group that the logic-app deploys resources into (i.e. databases)
flow-core-services-rg="logicapp-flow-test"
flow-managed-services-rg="logicapp-flow-managed-rg-test"
location="westeurope"

deploy-infra:	
	az group create \
		--resource-group ${flow-core-services-rg} \
		--location ${location}

	az group create \
		--resource-group ${flow-managed-services-rg} \
		--location ${location}

	mkdir dist
	az bicep build \
		-f ./infra/main.bicep \
		--outdir dist

	az deployment group create \
		-g ${flow-core-services-rg} \
		--template-file dist/main.json \
		--parameters sqlAADAdminUsername=${sqlAADAdminUsername} sqlAADAdminObjectId=${sqlAADAdminObjectId}
	
	# NOTE: Work-in-progress - buggy
	# Assigns 'Owner' permission of the resource group to the logic app. Seems to not work very well although
	# running the commands individualy in WSL did work for me.
	identity=`az resource list -g logicapp-flow-test --resource-type 'Microsoft.Web/sites' --query [0].identity.principalId -o tsv`; \
	scope=`az group list --query "[?name=='${flow-managed-services-rg}'].id" -o tsv`; \
	echo "LogApp identity = $${identity}"; \
	echo "Resource-group scope = $${scope}"; \
	x=`az role assignment create --role "Owner" --assignee "$${identity}" --scope "$${scope}"`; \

clean-dist:
	rm -rf dist

clean: clean-dist
	az group delete --resource-group ${flow-core-services-rg} 
	az group delete --resource-group ${flow-managed-services-rg}
	
.PHONY: all clean clean-dist