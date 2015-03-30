#
# You can use this script to query AD for any
# active AD accounts with a valid email address.
# It will write them to a series of input files. 
# TABCMD will use these files to import users and
# add users to a default group.
#
import-module ActiveDirectory
###################################################################
# BEGIN USER CONFIGURED CHOICES
#
# These are for the AD portion of the script.
#   Change the number of days to go back and query ID's
#   Change the number to 0 to query everything.
    $DAYS = 2
#   Root Path
    $SERVER = '****.net'
#   OU
    $BASE = 'ou=****,ou=****,dc=****,dc=****'
#   Search Scope (Base, OneLevel, Subtree)
    $SCOPE = 'Subtree'
#   This is where to change if different properties required for your search.  
    $PROPERTIES = 'CN' , 'DisplayName', 'EmailAddress' , 'WhenCreated'
#   Mail Domain Filter
#   Primary mail domain.  Use "*" for all mail domains.
    $MailFilter = "yourmaildomain.com"
#   Path for the list of users with properties (tabcmd createuser)
    $ADUsers_All = "X:\Path for master file\ADUsers_All.csv"
#   Path for the list of users no properties (tabcmd adduser)
    $ADUsers_ID = "X:\Path for master file\ADUsers_ID.csv"
#   Split the large file.  How many users in each small file?
    $destinationfilesize = "200" 
#   Destination folder to create the small files 
    $userfolderpath = "X:\Path for input files\user" 
    $groupfolderpath = "X:\Path for input files\group"
#
#
# These are for the TABCMD portion of the script.
#   Path for the TABCMD
    $TabPath = "X:\Tableau\Tableau Server\8.3\bin"
#   ID for TABCMD in quotes
    $TabID = "****"
#   Password for TABCMD in quotes
    $TabPSWD = "****"
#   Tableau URL
    $TabURL = "https://url4yourtableausite.net"
#   Global parameters for TABCMD
    $TabParam = "--no-certcheck"
#   Optional parameters
    $TabOpParam = "--no-complete"
#   Specify a tableau group
    $TabGroup = "DefaultGroupName"
#
#   Begin mail settings.  If you don't have mail capability then you can remove this part.
#   The line of code below can be used to send the email.
#
#   $smtpClient.Send( $smtpMessage)
#
#   Begin smtp mail settings
#   Change the smtp server and port below.
    $smtpServer = "yoursmtpserver.net"
    $smtpPort = "25"
    $smtpMessage = New-Object System.Net.Mail.MailMessage
#   Change the from address
    $smtpMessage.From = "someaddress@yourmaildomain.com"
#   Add or Remove people from the notification list - comma seperated.
    $smtpMessage.To.Add("someaddress@yourmaildomain.com")
#   Subject : Change your email subject below.
    $smtpMessage.Subject = "Subject line for email"
#   Body
    $smtpMessage.IsBodyHtml = "False"
    $smtpMessage.Body = $smtpBody
#   Body : Change your email message below.
    $smtpMessage.Body = "This is the email body.  $sourcelinecount users imported today."

#   No need to change the settings below.
    $smtpClient = New-Object System.Net.Mail.SmtpClient( $smtpServer , $smtpPort )
#
# END USER CONFIGURED CHOICES
#####################################################################

# Calculates the current date minus number of days. 
# Applies Mail Domain Filter
# Adds filters to parameter.
If ($DAYS -gt 0) {
    $Duration = (GET-DATE).AddDays(-$DAYS) 
    $OUFILTER = 'WhenCreated -ge $Duration -and EmailAddress -like $MailFilter'
    }
Else {
$OUFILTER = 'EmailAddress -like $MailFilter'
}
 
$ADUserParams=@{
'Server' = $SERVER 
'Searchbase' = $BASE 
'Searchscope'= $SCOPE
'Properties' = $PROPERTIES
'Filter' = $OUFilter
}

$SelectParams=@{
'Property' = $PROPERTIES
}
 
get-aduser @ADUserParams |
select-object @SelectParams | 

#
# This part of the script is used to define each column type and add additional columns as required.
# Columns must be in this order for Tableau to use as an import file.  (username, password, full name, license, admin, publisher, email)
#
%{ $ADObj = New-Object PSObject
#Username
Add-Member -InputObject $ADObj -MemberType NoteProperty -name "CN" -value $_.CN.toLower()
#Password - Here we are adding a blank column which is required by the import script.
Add-Member -InputObject $ADObj -MemberType NoteProperty -name "TableauPassword" -value ""
#Full Name
Add-Member -InputObject $ADObj -MemberType NoteProperty -name "DisplayName" -value $_.DisplayName
#License Level (Interactor, Viewer, or Unlicensed)
Add-Member -InputObject $ADObj -MemberType NoteProperty -name "TableauLicense" -value "Viewer"
#Administrator (System, Site, Site or None)
Add-Member -InputObject $ADObj -MemberType NoteProperty -name "TableauAdmin" -value ""
#Publisher (yes/true/1 or no/false/0)
Add-Member -InputObject $ADObj -MemberType NoteProperty -name "TableauPublish" -value "0"
#Email Address
Add-Member -InputObject $ADObj -MemberType NoteProperty -name "EmailAddress" -value $_.EmailAddress
$ADObj } | 

# Done querying Active Directory Writing the ADUsers_All.csv now.

ConvertTo-CSV -notype | Select -skip 1 | %{ $_ -replace '"',"" } | out-file $ADUsers_All -force -Encoding Ascii

# 
# Split a user file into smaller files. 
# This will take a while with large files. 
#  
# Set the baseline counters  
# Set the line counter to 0 
$linecount = 0 
# Set the file counter to 1. This is used for the naming of the log files 
$filenumber = 1 

# Find the current line count to present to the user before asking the new line count for chunk files 
Get-Content $ADUsers_All | Measure-Object | ForEach-Object { $sourcelinecount = $_.Count } 
 
#Tell me how large the current file is 
Write-Host "Your current file size is $sourcelinecount lines long" 
 
# The new size is a string, so we convert to integer and up 
# Set the upper boundary (maximum line count to write to each file) 
$maxsize = [int]$destinationfilesize  
 
Write-Host "File is $ADUsers_All - destination is $userfolderpath - new file line count will be $destinationfilesize" 
 
# This reads each line of the source file, writes it to the target file and increments the line counter. 
$content = get-content $ADUsers_All | % { 
 Add-Content $userfolderpath\AllUsers$filenumber.csv "$_" 
  $linecount ++ 
  If ($linecount -eq $maxsize) { 
    $filenumber++ 
    $linecount = 0 
  } 
} 
 
# Clean up, clean up, everybody clean up. 
[gc]::collect()  
[gc]::WaitForPendingFinalizers() 

get-aduser @ADUserParams | 
select-object @SelectParams | 

#
# This part of the script is used to define just the userid.
# This file will be used to import the users into a default group, Tableau requires a single entry per row.
#
%{ $ADObj = New-Object PSObject
#Username
Add-Member -InputObject $ADObj -MemberType NoteProperty -name "CN" -value $_.CN.toLower()
$ADObj } | 

ConvertTo-CSV -notype | Select -skip 1 | %{ $_ -replace '"',"" } | out-file $ADUsers_ID -force -Encoding Ascii

# 
# Split a user group file into smaller files. 
# This will take a while with large files.
#  
# Set the baseline counters  
# Set the line counter to 0 
$linecount = 0 
# Set the file counter to 1. This is used for the naming of the log files 
$filenumber = 1 

# Find the current line count to present to the user before asking the new line count for chunk files 
Get-Content $ADUsers_ID | Measure-Object | ForEach-Object { $sourcelinecount = $_.Count } 
 
#Tell me how large the current file is 
Write-Host "Your current file size is $sourcelinecount lines long" 
 
# The new size is a string, so we convert to integer and up 
# Set the upper boundary (maximum line count to write to each file) 
$maxsize = [int]$destinationfilesize  
 
Write-Host "File is $ADUsers_ID - destination is $groupfolderpath - new file line count will be $destinationfilesize" 
 
# This reads each line of the source file, writes it to the target file and increments the line counter. 
$content = get-content $ADUsers_All | % { 
 Add-Content $groupfolderpath\AllIDs$filenumber.csv "$_" 
  $linecount ++ 
  If ($linecount -eq $maxsize) { 
    $filenumber++ 
    $linecount = 0 
  } 
} 
 
# Clean up, clean up, everybody clean up. 
[gc]::collect()  
[gc]::WaitForPendingFinalizers() 

####  END  INPUT FILES ####

####  BEGIN TABCMD  ####

# Login tableau user
cd $TabPath
.\tabcmd login -s $TabURL -u $TabID -p $TabPSWD $TabParam

# Import new users
# Grab the files and put them in an array.
$ADUserfiles = Get-ChildItem $userfolderpath\*.csv
foreach ($Ufile in $ADUserfiles)
{
  # Import new users
.\tabcmd createusers $Ufile $TabOpParam $TabParam 
}

# Import new users into group
# Grab the files and put them in an array.
$ADGroupfiles = Get-ChildItem $groupfolderpath\*.csv
foreach ($Gfile in $ADGroupfiles)
{
  # Add new users to group
.\tabcmd addusers  $TabGroup --users $GFile $TabOpParam $TabParam
}

# Logout tableau user
.\tabcmd logout

####  End TABCMD  ####

# Cleaning up the mess now. Removing all the smaller files wich are no longer needed.
Remove-Item $userfolderpath\*.csv -recurse
Remove-Item $groupfolderpath\*.csv -recurse

# Sending the wrapup email to server admins.
# $smtpClient.Send( $smtpMessage)
