# logic-app-flow

## Structure
- Infra: contains bicep file + parameters for deployment

## Deploy:
Deploy infrastructure + workflow to azure:
$make clean-dist && make deploy-infra
- optional:
    specify resource group and location 
    ($make clean-dist && make deploy-infra rg="<your_resource_group>" location="<your_location>")

## Clean up
Clean up resources deployed to Azure
$make clean
