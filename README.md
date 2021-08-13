# logic-app-flow

## Prerequisites
- Windows Subsystem for Linux [WSL](https://docs.microsoft.com/en-us/windows/wsl/about)
- Make (comes typically with WSL)

## Structure
- [/infa](/infra) Contains bicep templates for resource deployment
- [/app](/app) Contains JSON representation of logic app

## Getting started
Deploy infrastructure + workflow to azure:
```
$make clean-dist && make deploy-infra
```

Deploy into specific resource-group and/or region
```
$make clean-dist && make deploy-infra rg="<your_resource_group>" location="<your_location>")
```

## Clean up
Clean up resources deployed to Azure
$make clean
