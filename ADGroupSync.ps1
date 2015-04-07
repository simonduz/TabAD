#### Connection Information ####
$DBServer = "your talbeau db server"
$DBPort = "8060"
$DBName = "workgroup"
$DBUID = "readonly"
$DBPSWD = "db password"

#### Export File ####
$OutPath = "F:\some path for the file\"
$OutFile = "groups filename.csv"

#### These are for the TABCMD portion of the script. ###
#   Path for the TABCMD
    $TabPath = "F:\Tableau\Tableau Server\8.3\bin"
#   ID for TABCMD
    $TabID = "tableau id"
#   Pswd for TABCMD
    $TabPSWD = "tableau password"
#   Tableau URL
    $TabURL = "https://tableauurl"
#   Global parameters for TABCMD
    $TabParam = "--no-certcheck"
#   Optional parameters
    $TabOpParam = "--no-complete"
#   Optional timeout
    $TabTime = "--timeout 3600"
########################################################

#### SQL Query ####
 $cSQL = "
    SELECT domains.id,
        domains.family,
        groups.id,
        groups.name,
        groups.site_id,
        sites.id,
        sites.url_namespace
    FROM public.domains domains
    INNER JOIN public.groups groups ON (domains.id = groups.domain_id)
    INNER JOIN public.sites sites ON (groups.site_id = sites.id)
    WHERE (domains.family = 'ActiveDirectory' AND sites.url_namespace != '')
    "
    
    function Get-ODBC-Data
    {
       param([string]$serverName=$(throw 'serverName is required.'),
			 [string]$databaseName=$(throw 'databaseName is required.'),
			 [string]$query=$(throw 'query is required.'))

      $conn=New-Object System.Data.Odbc.OdbcConnection
      $connStr = "Driver={PostgreSQL Unicode(x64)};Server=$DBServer;Port=$DBPort;Database=$DBName;Uid=$DBUID;Pwd=$DBPSWD;"
      $conn.ConnectionString= $connStr
      # display :
      " "
      "Connection :"
      $connStr
      " "
      "SQL :"
      $query
      " "
      [void]$conn.open
      $cmd=new-object System.Data.Odbc.OdbcCommand($query,$conn)
      $cmd.CommandTimeout=15
      $ds=New-Object system.Data.DataSet
      $da=New-Object system.Data.odbc.odbcDataAdapter($cmd)
      [void]$da.fill($ds)
      #$da.fill($ds) | out-null
      $ds.Tables[0] | 
      Select-Object name,url_namespace |
      ConvertTo-CSV -notype | %{ $_ -replace '"',"" } | out-file $OutPath$OutFile -force -Encoding Ascii
      [void]$conn.close()
    }
    # main:
    Get-ODBC-Data -server $DBServer -port $DBPort  -database $DBName -query $cSQL

####  BEGIN TABCMD  ####
cd $TabPath
# Sync AD Groups
# Grab the file and put contents in an array.
$ADGroupFiles = Import-Csv $OutPath$OutFile 
foreach ($object in $ADGroupFiles)
{
$GroupName = $object.name
$URL = $object.url_namespace
# Login tableau server with correct siteid
.\tabcmd login -s $TabURL -t $URL -u $TabID -p $TabPSWD $TabParam $TabTime
# Sync AD Groups
.\tabcmd syncgroup "$GroupName" $TabParam $TabOpParam
# Logout tableau server
.\tabcmd logout
}
####  End TABCMD  ####
