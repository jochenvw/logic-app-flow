rg="logicapp-flow-test"
location="westeurope"

deploy-infra:
	mkdir dist
	az group create \
		--resource-group ${rg} \
		--location ${location}
	az bicep build \
		-f ./infra/main.bicep \
		--outdir dist
	az deployment group create \
		-g ${rg} \
		--template-file dist/main.json \
		--parameters @infra/parameters.json

clean-dist:
	rm -rf dist

clean: clean-dist
	az group delete --resource-group ${rg}	
	
.PHONY: all clean clean-dist
