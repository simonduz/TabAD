# TabAD
Tableau Import AD users : Powershell
This script is currently running as a scheduled task on Windows Server and has successfully imported 75k+ users.

What this script currently does:
It queries AD for all active accounts with a valid email address based on a defined range of days. (or it will do all accounts)
  You can define the OU parameters and the mail domain
It writes the user information to a series of CSV files along with the required Tableau fields for account creation.
  You can set the number of accounts per file and the input locations.
  You can customize the required fields.
  These files will be used to add new user accounts to Tableau server.
It writes a separate set of files containing just the userid's.
  These files will be used to add new users to a default Tableau group.
It logs onto Tableau server, defined in the parameters.
It launches tabcmd and loops through the input files adding users in bulk.
  It will skip any user ID's that don't match the required fields.
It launches tabcmd and loops through the group input files adding all the new users to a default group.
Logs off Tableau server
Performs a cleanup deleting the smaller input files, but keeping the 2 master input files.
It will send an email with the status of the input.

Future state I will add an account deletion section.   
Based on an input file tabcmd will delete userid's that were removed from AD.
