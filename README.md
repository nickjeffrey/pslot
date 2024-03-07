# pslot
pslot validator / visualizer for Virtual SCSI and Virtual Fibre Channel slots in a PowerVM environment

Forked from the original script by Brian Smith at https://pslot.sourceforge.net/

pslot is a Perl program designed to anaylize, validate, and optionally visualize the VSCSI and Virtual Fibre Channel (VFC) slots in a PowerVM environment. 

Virtual Slots in PowerVM must be setup in pairs, and are very easy to misconfigure.   Here is an example of a properly configured pair:
<img src=images/vscsi_map.jpg>

Each VSCSI or VFC client/server pair in made up of 8 items:
- VIO server name (defined in server adapter)
- VIO local slot (defined in server adapter)
- Remote partition (defined in server adapter)
- Remote slot (defined in server adapter)
- LPAR server name (defined in client adapter)
- LPAR local slot (defined in client adapter)
- Remote VIO partition (defined in client adapter)
- Remote VIO slot (defined in client adapter)

If one or more of the 8 items above are incorrect the client/server will not be able to establish a VSCSI or VFC connection.  

The pslot program validates that every VSCSI or VFC adapter on server is correctly paired and that each of the 8 items line up correctly.  If any virtual adapters don't line up with a corresponding adapter pslot will alert you. 

pslot can run in either text mode or a Graphviz mode where it can produce visual representations of the VSCSI or VFC slots. 

To run pslot you must put the script on a server that has SSH keys setup with your HMC.   If you would like to do the optional visualization you will also need to have Graphviz installed.  I recommend using Graphviz on Linux because it is in most distro's repositories and very easily installable.  It is also possible to install Graphviz on AIX, but more difficult.  See http://www.perzl.org/aix/ for AIX binaries of Graphviz.

# pslot Screen Shots

Here is a screen slot of plot running in the text mode.   You can easily grep for "^ERROR" to only see problems.   In this example there is a misconfigured server/client pair (client should be pointing to vio2, not vio1).   This misconfiguration causes the server/client adapters to not be paired correctly and to show an error: 
<img src=images/screenshot6.png>

Here is an example diagram created from the script in graphviz mode:
<img src=images/screenshot1.png>


Here is a screenshot produced in graphviz mode when one of the VSCSI client/server slots is misconfigured:
<img src=images/screenshot2.png>

Here is a screenshot showing that pslot understands VSCSI server adapters configured for "any" remote parititon:
<img src=images/screenshot3.png>

Here is a screenshot showing it in the "left to right" mode ("-s" argument) which fits the screen better if you have a lot of LPAR's:
<img src=images/screenshot4.png>

Here is a screenshot showing Virtual Fibre Channel adapters being displayed:
<img src=images/vfc.png>


# Installation / Use

Download the script from:  https://sourceforge.net/projects/pslot/files/
or
```
git clone https://github.com/nickjeffrey/pslot
cd pslot
chmod +x pslot.pl
```

You must run the script from a server that has SSH keys setup with your HMC.  

```
Usage ./pslot.pl -h hmcserver -m managedsystem { -v | -f } [-l lpar] [-r min-max] [-d] [-s]
 -h specifies hmcserver name (can also be username@hmc)
 -m specifies managed system name
 { -v | -f } specify either -v (Virtual SCSI) or -f (Virtual Fibre Channel)
 [-l lpar] only report/graph on specific lpar and its VIO servers
 [-r min-max] only report/graph range of VIO server slots. 
    Example: "-r 40-50" will graph slot pairs that have VIO server slots between 40 to 50
 -d turn on Graphviz dot output mode
 -s Display graph left to right in Graphviz mode
```

# Examples:
```
VSCSI graphviz mode:
   ./pslot.pl -h hscroot@hmcserver1 -m p520 -v -d -s
VSCSI text mode:     
   ./pslot.pl -h hscroot@hmcserver1 -m p520 -v
VFC graphviz mode:   
   ./pslot.pl -h hscroot@hmcserver1 -m p520 -f -d -s
VFC text mode:       
   ./pslot.pl -h hscroot@hmcserver1 -m p520 -f
VFC graphviz mode, only graph lpar1    
   ./pslot.pl -h hscroot@hmcserver1 -m p520 -l lpar1 -f -d -s
VSCSI graphviz mode, only graph slot pairs with VIO slots between 40-60
   ./pslot.pl -h hscroot@hmcserver1 -m p520 -r 40-60 -v -d -s
```

When run in Graphviz mode ("-d" flag) it will produce DOT code that graphviz can turn in to a graph.   If you would like to do the optional visualization you will also need to have Graphviz installed.  I recommend using Graphviz on Linux because it is in most distro's repositories and very easily installable.  It is also possible to install Graphviz on AIX, but more difficult.  See http://www.perzl.org/aix/ for AIX binaries of Graphviz.

You can run the script like this to create a graph:
```
./pslot.pl -h hscroot@hmcserver1 -m p520 -v -d -s  | dot -Tpng -o vscsi.png
```

# Graphing with large servers / lots of LPAR's

If you are trying to graph a server that has more than 20 or 30 LPAR's the graphs might get too big and not be very helpful.   There is the "-r min-max" flag to specify slot pairs that have a certain range of VIO server slots.   Using this you can break up a large server in to several smaller graphs.   There is also the "-l lpar" option to graph a single lpar.  

Here are some example commands of breaking up a large server in to several smaller graphs:
```
./pslot.pl -h hscroot@hmcserver1 -m p520 -v -d -s -r 20-40  | dot -Tpng -o server1.png
./pslot.pl -h hscroot@hmcserver1 -m p520 -v -d -s -r 41-60  | dot -Tpng -o server2.png
./pslot.pl -h hscroot@hmcserver1 -m p520 -v -d -s -r 61-80  | dot -Tpng -o server3.png
```

# Related scripts
http://www.ibm.com/developerworks/aix/library/au-aix-graphviz/index.html?ca=drs-

http://graphlvm.sourceforge.net/


# License / Disclaimer
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.




