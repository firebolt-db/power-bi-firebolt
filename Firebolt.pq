// This file contains your Data Connector logic
[Version = "0.1.0"]
section Firebolt;


// When set to true, additional trace information will be written out to the User log.
// This should be set to false before release. Tracing is done through a call to
// Diagnostics.LogValue(). When EnableTraceOutput is set to false, the call becomes a
// no-op and simply returns the original value.
EnableTraceOutput = true;

/****************************
 * ODBC Driver Configuration
 ****************************/
// The name of your ODBC driver.
//
Config_DriverName = "ClickHouse ODBC Driver (ANSI)";

Config_SqlConformance = ODBC[SQL_SC][SQL_SC_SQL92_FULL];
Config_LimitClauseKind = LimitClauseKind.LimitOffset;
Config_DefaultUsernamePasswordHandling = false;
Config_UseParameterBindings = false;
Config_StringLiteralEscapeCharacters  = { "'" }; // ex. { "'" } or { {"\", "\\"}, {"'", "\'"} }
Config_UseCastInsteadOfConvert = true;
Config_EnableDirectQuery = true;


[DataSource.Kind="Firebolt", Publish="Firebolt.Publish"]
shared Firebolt.Contents = Value.ReplaceType(FireboltImpl, DatabaseType);

DatabaseType = type function (
    account as (type text meta [
        Documentation.FieldCaption = "Account",
        Documentation.FieldDescription = "Account name in Firebolt",
        Documentation.SampleValues = {"my-account"}  
    ]),
    engine as (type text meta [
        Documentation.FieldCaption = "Engine",
        Documentation.FieldDescription = "Name of Firebolt engine",
        Documentation.SampleValues = {"my-engine"}  
    ]),
    database as (type text meta [
        Documentation.FieldCaption = "Database",
        Documentation.FieldDescription = "Name of Firebolt database",
        Documentation.SampleValues = {"my-database"}  
    ]),
    optional env as (type text meta [
        Documentation.FieldCaption = "Env",
        Documentation.FieldDescription = "Environment name",
        Documentation.SampleValues = {"Staging", "Production"}
    ]),
    optional logfile as (type text meta [
        Documentation.FieldCaption = "Log File",
        Documentation.FieldDescription = "Path to the log file"
    ]))
    as table meta [
        Documentation.Name = "Firebolt",
        Documentation.LongDescription = "Firebolt ODBC connector for Power Query",
        Documentation.Examples = {[]}
    ];

FireboltImpl = (account as text, engine as text, database as text, optional env as text, optional logfile as text) as table =>
    let
        ConnectionString = [
            Driver = Config_DriverName,
            // Server = Server,
            Env = env,
            Account = account,
            Engine = engine,
            Database = database,
            DriverLogFile = logfile
        ],
        defaultConfig = Diagnostics.LogValue("BuildOdbcConfig", BuildOdbcConfig()),
        
        Credential = Extension.CurrentCredential(),
        CredentialConnectionString =
            if Credential[AuthenticationKind]? = "UsernamePassword" then
                // set connection string parameters used for basic authentication
                [UID = Credential[Username], PWD = Credential[Password]]
            else
                error Error.Record("Error", "Unhandled authentication kind: " & Credential[AuthenticationKind]?),
        SqlCapabilities = Diagnostics.LogValue(
            "SqlCapabilities_Options", defaultConfig[SqlCapabilities] & [
                // Place custom overrides here
                // The values below are required for the SQL Native Client ODBC driver, but might
                // not be required for your data source.
                FractionalSecondsScale = 3
            ]
        ),
        // Please refer to the ODBC specification for SQLGetInfo properties and values.
        // https://github.com/Microsoft/ODBC-Specification/blob/master/Windows/inc/sqlext.h
        SQLGetInfo = Diagnostics.LogValue(
            "SQLGetInfo_Options",
            defaultConfig[SQLGetInfo]
                & [
                    // Place custom overrides here
                    // The values below are required for the SQL Native Client ODBC driver, but might
                    // not be required for your data source.
                    SQL_SQL92_PREDICATES = ODBC[SQL_SP][All],
                    SQL_AGGREGATE_FUNCTIONS = ODBC[SQL_AF][All]
                ]
        ),
        // SQLGetTypeInfo can be specified in two ways:
        // 1. A #table() value that returns the same type information as an ODBC
        //    call to SQLGetTypeInfo.
        // 2. A function that accepts a table argument, and returns a table. The
        //    argument will contain the original results of the ODBC call to SQLGetTypeInfo.
        //    Your function implementation can modify/add to this table.
        //
        // For details of the format of the types table parameter and expected return value,
        // please see: https://docs.microsoft.com/en-us/sql/odbc/reference/syntax/sqlgettypeinfo-function
        SQLGetTypeInfo = (types) =>
            if (EnableTraceOutput <> true) then
                types
            else
                let
                    // Outputting the entire table might be too large, and result in the value being truncated.
                    // We can output a row at a time instead with Table.TransformRows()
                    rows = Table.TransformRows(types, each Diagnostics.LogValue("SQLGetTypeInfo " & _[type_name], _)),
                    toTable = Table.FromRecords(rows)
                in
                    Value.ReplaceType(toTable, Value.Type(types)),
        // SQLColumns is a function handler that receives the results of an ODBC call
        // to SQLColumns(). The source parameter contains a table with the data type
        // information. This override is typically used to fix up data type mismatches
        // between calls to SQLGetTypeInfo and SQLColumns.
        //
        // For details of the format of the source table parameter, please see:
        // https://docs.microsoft.com/en-us/sql/odbc/reference/syntax/sqlcolumns-function
        SQLColumns = (catalogName, schemaName, tableName, columnName, source) =>
            let
                OdbcSqlType.BIT = -7,
                OdbcSqlType.BOOLEAN = 249,
                OdbcSqlType.SQL_TINYINT = -6,
                OdbcSqlType.INT8 = 250,
                OdbcSqlType.SQL_BIGINT = -5,
                OdbcSqlType.INT64 = 251,
                FixDataType = (dataType) =>
                    if dataType = OdbcSqlType.BOOLEAN then
                        OdbcSqlType.BIT
                    else if dataType = OdbcSqlType.INT8 then
                        OdbcSqlType.SQL_TINYINT                            
                    else if dataType = OdbcSqlType.INT64 then
                        OdbcSqlType.SQL_BIGINT
                    else
                        dataType,
                // Not sure if this is needed
                FixDataTypeName = (dataTypeName) =>
                    if dataTypeName = "TEXT" then
                        "SQL_WVARCHAR"
                    else
                        dataTypeName,
                Transform = Table.TransformColumns(source, {{"data_type", FixDataType}
//                     , {"TYPE_NAME", FixDataTypeName}
                })
           in
                if (EnableTraceOutput <> true) then
                    Transform
                else if (
                    // the if statement conditions will force the values to evaluated/written to diagnostics
                    Diagnostics.LogValue("SQLColumns.TableName", tableName) <> "***"
                    and Diagnostics.LogValue("SQLColumns.ColumnName", columnName) <> "***"
                ) then
                    let
                        // Outputting the entire table might be too large, and result in the value being truncated.
                        // We can output a row at a time instead with Table.TransformRows()
                        rows = Table.TransformRows(Transform, each Diagnostics.LogValue("SQLColumns", _)),
                        toTable = Table.FromRecords(rows)
                    in
                        Value.ReplaceType(toTable, Value.Type(Transform))
                else
                    Transform,
        // Remove null fields from the ConnectionString
        ConnectionStringNoNulls = Record.SelectFields(
            ConnectionString, Table.SelectRows(Record.ToTable(ConnectionString), each [Value] <> null)[Name]
        ),
        OdbcDatasource = Odbc.DataSource(
            ConnectionStringNoNulls,
            [
                // A logical (true/false) that sets whether to view the tables grouped by their schema names
                HierarchicalNavigation = true,
                // Allows upconversion of numeric types
                SoftNumbers = true,
                // Allow upconversion / resizing of numeric and string types
                TolerateConcatOverflow = true,
                // Enables connection pooling via the system ODBC manager
                ClientConnectionPooling = true,
                // These values should be set by previous steps
                CredentialConnectionString = CredentialConnectionString,
                SqlCapabilities = SqlCapabilities,
                SQLColumns = SQLColumns,
                SQLGetInfo = SQLGetInfo,
                
                SQLGetTypeInfo = SQLGetTypeInfo
            ]
        )
    in
        OdbcDatasource;

// Data Source Kind description
Firebolt = [
    // Set the TestConnection handler to enable gateway support.
    // The TestConnection handler will invoke your data source function to
    // validate the credentials the user has provider. Ideally, this is not
    // an expensive operation to perform. By default, the dataSourcePath value
    // will be a json string containing the required parameters of your data
    // source function. These should be parsed and parsed as individual parameters
    // to the specified data source function.
    TestConnection = (dataSourcePath) =>
        let
            json = Json.Document(dataSourcePath), env = json[env], account = json[account], engine = json[engine], database = json[database]
            // name of function parameter
        in
            {"Firebolt.Contents", env, account, engine, database},
    Authentication = [
        // We use id and secret, but for PBI it's renamed username password behind the scenes
        UsernamePassword = [
            UsernameLabel = Extension.LoadString("UsernameLabel"),
            PasswordLabel = Extension.LoadString("PasswordLabel"),
            Label = Extension.LoadString("AuthenticationLabel")
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
Firebolt.Publish = [
    Beta = true,
    Category = "Database",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://firebolt.io",
    SupportsDirectQuery = Config_EnableDirectQuery,
    SourceImage = Firebolt.Icons,
    SourceTypeImage = Firebolt.Icons
];

Firebolt.Icons = [
    Icon16 = { Extension.Contents("Firebolt16.png"), Extension.Contents("Firebolt20.png"), Extension.Contents("Firebolt24.png"), Extension.Contents("Firebolt32.png") },
    Icon32 = { Extension.Contents("Firebolt32.png"), Extension.Contents("Firebolt40.png"), Extension.Contents("Firebolt48.png"), Extension.Contents("Firebolt64.png") }
];


// build settings based on configuration variables
BuildOdbcConfig = () as record =>
    let
        Merge = (previous as record, optional caps as record, optional funcs as record, optional getInfo as record) as record =>
            let
                newCaps = if (caps <> null) then previous[SqlCapabilities] & caps else previous[SqlCapabilities],
                newFuncs = if (funcs <> null) then previous[SQLGetFunctions] & funcs else previous[SQLGetFunctions],
                newGetInfo = if (getInfo <> null) then previous[SQLGetInfo] & getInfo else previous[SQLGetInfo]
            in
                [SqlCapabilities = newCaps, SQLGetFunctions = newFuncs, SQLGetInfo = newGetInfo],
        defaultConfig = [
            SqlCapabilities = [],
            SQLGetFunctions = [],
            SQLGetInfo = []
        ],
        withParams =
            if (Config_UseParameterBindings = false) then
                let
                    caps = [
                        SupportsNumericLiterals = true,
                        SupportsStringLiterals = true,
                        SupportsOdbcDateLiterals = true,
                        SupportsOdbcTimeLiterals = true,
                        SupportsOdbcTimestampLiterals = true
                    ],
                    funcs = [
                        SQL_API_SQLBINDPARAMETER = false
                    ]
                in
                    Merge(defaultConfig, caps, funcs)
            else
                defaultConfig,
        withEscape =
            if (Config_StringLiteralEscapeCharacters <> null) then
                let
                    caps = [
                        StringLiteralEscapeCharacters = Config_StringLiteralEscapeCharacters
                    ]
                in
                    Merge(withParams, caps)
            else
                withParams,
        withLimitClauseKind = let caps = [
            LimitClauseKind = Config_LimitClauseKind
        ] in Merge(withEscape, caps),
        withCastOrConvert =
            if (Config_UseCastInsteadOfConvert <> null) then
                let
                    value =
                        if (Config_UseCastInsteadOfConvert = true) then
                            ODBC[SQL_FN_CVT][SQL_FN_CVT_CAST]
                        else
                            ODBC[SQL_FN_CVT][SQL_FN_CVT_CONVERT],
                    getInfo = [
                        SQL_CONVERT_FUNCTIONS = value
                    ]
                in
                    Merge(withLimitClauseKind, null, null, getInfo)
            else
                withLimitClauseKind,
        withSqlConformance =
            if (Config_SqlConformance <> null) then
                let
                    getInfo = [
                        SQL_SQL_CONFORMANCE = Config_SqlConformance
                    ]
                in
                    Merge(withCastOrConvert, null, null, getInfo)
            else
                withCastOrConvert
    in
        withSqlConformance;

//
// Load common library functions
//
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name), asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

// Diagnostics module contains multiple functions. We can take the ones we need.
Diagnostics = Extension.LoadFunction("Diagnostics.pqm");

Diagnostics.LogValue = if (EnableTraceOutput) then Diagnostics[LogValue] else (prefix, value) => value;

// OdbcConstants contains numeric constants from the ODBC header files, and a
// helper function to create bitfield values.
ODBC = Extension.LoadFunction("OdbcConstants.pqm");
