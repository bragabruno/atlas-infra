# Terraform Module Dependency Graph

Module composition and dependency order for `atlas-infra`. Environments (`envs/dev`, `envs/prod`) instantiate all modules; state is stored in Azure Blob Storage.

```mermaid
flowchart TD
    STATE["State Backend\nAzure Blob Storage\n(lease locking)"]

    subgraph ENVS["envs/"]
        DEV["envs/dev"]
        PROD["envs/prod"]
    end

    subgraph MODULES["infra/terraform/modules/"]
        NET["network\n(VNet, subnets, NSGs)"]
        AKS["aks\n(cluster, node pools,\nOIDC issuer, Workload Identity)"]
        IDN["identity\n(managed identities,\nfederated credentials,\nrole assignments)"]
        SEC["secrets\n(Key Vault,\nCSI driver,\nSecretProviderClass)"]
        DATA["data\n(PostgreSQL Flexible Server,\nRedis)"]
        STOR["storage\n(Blob containers,\nACR)"]
    end

    subgraph PLATFORM["platform/ Helm charts\n(deployed via Skaffold / make cloud-up)"]
        KAFKA["kafka\n(Strimzi or Event Hubs)"]
        QDRANT["qdrant"]
        ES["elasticsearch"]
        MLFLOW["mlflow"]
        OTEL["otel-collector"]
        CC["cost-controls\n(scale-to-zero CronJob)"]
    end

    DEV -->|"compose"| NET

    NET --> AKS

    AKS --> IDN
    AKS --> SEC
    AKS --> DATA
    AKS --> STOR

    IDN -.->|"provides identities to"| SEC
    IDN -.->|"provides identities to"| DATA
    IDN -.->|"provides identities to"| STOR

    AKS -.->|"cluster hosts"| PLATFORM

    DEV <-->|"remote state"| STATE
```
