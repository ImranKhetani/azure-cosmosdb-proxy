# terraform.tfvars
subscription_id      = "<Enter_Subscription_ID>"
location             = "southeastasia"
resource_group_name  = "rg-cosmos-proxy"

# Networking
vnet_name            = "vnet-cosmos-proxy"
subnet_name          = "snet-appservice"

# App Service
app_service_plan_name = "asp-cosmos-proxy"
app_service_name      = "as-cosmos-proxy"

# Cosmos DB
# must be unique globally, 3–44 lowercase alphanumeric
cosmos_account_name   = "<enter_account_name>"
