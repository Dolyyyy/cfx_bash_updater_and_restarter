cfx_bash_updater_and_restarter

Overview:
----------
The CFX Updater/Restart Tool is a bash script that helps server admins update FiveM server artifacts and manage server restarts via 'screen' sessions. It provides an easy menu to:

- Update the server to the latest artifact version.
- Stop and restart the server in a new screen session.
- Attach to existing screen sessions.

Prerequisites:
--------------
- Linux environment with bash installed.
- 'screen' package installed.
- A FiveM server set up.

Usage:
------
1. Clone the repository in your server home directory for example in ``/home/debian/fivem`` :
   
   ``git clone https://github.com/Dolyyyy/cfx_bash_updater_and_restarter``

2. Navigate to the directory:
   ``cd cfx_bash_updater_and_restarter``

3. Make the script executable:
   ``chmod +x cfx_updater_EN.sh``

4. Run the script:
   ``bash cfx_updater_EN.sh``

Menu Options:
-------------
- 1. Update the artifact:
   Fetch and install the latest FiveM/RedM server artifact.

- 2. Restart the server in a new screen:
   Stop an existing screen session and start a new one.

- 3. View an existing screen session:
   List and attach to an active screen session.

- 4. Quit:
   Exit the tool.

License:
--------
This project is licensed under the MIT License.
