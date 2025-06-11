# Firebolt Power BI Connector

This repository provides the Firebolt connector for Microsoft Power BI, allowing users to seamlessly integrate Firebolt data sources with Power BI for advanced analytics and reporting.

## Prerequisites

Before installing the connector, ensure you have Firebolt's ODBC driver installed on your machine. If you don't have the driver, please reach out to your Firebolt representative to obtain it. Once obtained, run the provided installation file and follow the installation wizard instructions to install the driver.

## Installation

1. Navigate to the [GitHub Releases](https://github.com/firebolt-db/power-bi-firebolt/releases) page.
2. Download the latest `.mez` connector file.
3. Place the downloaded `.mez` file into your Power BI custom connectors directory:
```
Documents\Power BI Desktop\Custom Connectors
```

### Enable custom connectors in Power BI Desktop

Power BI Desktop requires explicit permission to load custom connectors. To ensure the Firebolt connector loads correctly, you must enable loading of custom connectors without validation:

1. Restart Power BI Desktop.
2. Go to `File` → `Options and settings` → `Options` → `Security`.
3. Under `Data Extensions`, select "Allow any extension to load without validation or warning."  
   *(This step is necessary because custom connectors are not signed by Microsoft and Power BI Desktop blocks unsigned connectors by default for security reasons.)*
4. Restart Power BI Desktop again to apply changes.

## Adding Firebolt as a Data Source in Power BI

1. Open Power BI Desktop.
2. Click on `Get Data` → `More...`.
3. In the dialog, search for "Firebolt" and select the Firebolt connector.
4. Click `Connect`.
5. Enter your Firebolt connection details:
   - **Account**: Your Firebolt account name.
   - **Engine**: The name of the Firebolt engine you want to connect to.
   - **Database**: The name of your Firebolt database.
6. Select the Data Connectivity mode:
    - **Import**: Data is loaded into Power BI, enabling extensive functionality but requiring periodic refreshes and sufficient local memory to accommodate the dataset.
    - **DirectQuery**: Queries are executed directly on Firebolt in real-time, providing fast performance even on large datasets by leveraging Firebolt's optimized query engine.
7. Click `OK`.
8. Enter your service account credentials. Follow the [guide](https://docs.firebolt.io/guides/managing-your-organization/service-accounts#create-a-service-account) to generate them if you don't have them already.
   - **Client ID**: Your Firebolt service account id.
   - **Client Secret**: Your Firebolt service account secret.
6. Click `Connect` to establish the connection.
