# Azure Cosmos DB Proxy via App Service + NAT Gateway

This project contains Terraform infrastructure and a sample Node.js proxy app to provide a **static public IP** for accessing **Azure Cosmos DB** from on-premises networks.  

It solves the common requirement where firewalls can only whitelist **IP addresses**, while Cosmos DB endpoints are provided as **URLs**.

---

## 📐 Architecture

- **Azure NAT Gateway** with a **static Public IP** → whitelistable on-prem
- **Azure App Service (Linux)** → hosts a simple Node.js proxy app
- **Azure Cosmos DB (SQL API)** → backend database
- **Virtual Network + Subnet (delegated to App Service)** for outbound NAT integration

---

## 🔧 Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) `>= 1.1`
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) logged in:
  ```bash
  az login
  az account set --subscription "<your-subscription-id>"
  ```
- [Node.js](https://nodejs.org/en/download/) `>= 18` (only if you want to build/test proxy locally)

---

## 🚀 Deployment

### 1. Clone repo

```bash
git clone https://github.com/ImranKhetani/azure-cosmosdb-proxy.git
cd azure-cosmosdb-proxy
```

### 2. Initialize Terraform

```bash
terraform init -upgrade
```

### 3. Create `terraform.tfvars`

Copy the provided `terraform.tfvars.example` and update values:

```hcl
subscription_id      = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
location             = "southeastasia"
resource_group_name  = "rg-cosmos-proxy"
vnet_name            = "vnet-cosmos-proxy"
subnet_name          = "snet-appservice"
app_service_plan_name = "asp-cosmos-proxy"
app_service_name     = "as-cosmos-proxy"
cosmos_account_name  = "cosmosproxyacct001"
```

### 4. Apply Infra

```bash
terraform apply -var-file="terraform.tfvars"
```

Terraform outputs:
- **nat_public_ip** → Static IP to whitelist in on-prem firewall  
- **app_service_default_hostname** → Proxy endpoint  
- **cosmos_endpoint** → Cosmos DB endpoint  

---

## 🌐 Deploy Proxy App

### 1. Build and zip app

```bash
cd cosmos-proxy-app
npm install
zip -r ../cosmos-proxy-app.zip .
```

### 2. Deploy to App Service

```bash
az webapp deployment source config-zip   --resource-group rg-cosmos-proxy   --name as-cosmos-proxy   --src ../cosmos-proxy-app.zip
```

### 3. Test

```bash
# Health check
curl https://as-cosmos-proxy.azurewebsites.net/

# Insert item
curl -X POST https://as-cosmos-proxy.azurewebsites.net/items   -H "Content-Type: application/json"   -d '{"id":"1","name":"Test from Proxy"}'

# Query items
curl https://as-cosmos-proxy.azurewebsites.net/items
```

---

## 🗑 Cleanup

To remove all deployed infra:

```bash
terraform destroy -var-file="terraform.tfvars"
```

Cosmos DB deletion can take several minutes.

---

## 📂 Repo Structure

```
.
├── main.tf                  # Terraform infra definition
├── terraform.tfvars.example # Example config
├── cosmos-proxy-app/        # Node.js proxy app
│   ├── package.json
│   └── server.js
└── README.md
```

---

## 📝 Notes

- `.terraform/`, `terraform.tfstate*`, and `node_modules/` are **gitignored**.  
- For production, store Cosmos DB keys in **Azure Key Vault**, not App Service app settings.  
- Extendable to CI/CD via **GitHub Actions** or **Azure DevOps**.  

---

## 🔗 Resources

- [Azure NAT Gateway docs](https://learn.microsoft.com/azure/virtual-network/nat-gateway/nat-overview)  
- [Azure App Service VNet Integration](https://learn.microsoft.com/azure/app-service/overview-vnet-integration)  
- [Azure Cosmos DB docs](https://learn.microsoft.com/azure/cosmos-db/introduction)  
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)  
