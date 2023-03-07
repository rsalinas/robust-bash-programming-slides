---
title: Robust shell programming. 
subtitle: Tips for improving shell scripts
author: Raúl Salinas-Monteagudo
email: rausalinas@gmail.com
date: 2023-03-10
comment:  This is a comment intended to demonstrate  
          metadata that spans multiple lines, yet  
          is treated as a single value.  
---

# Motivation

- bash is very old (1989), archeology
- Interpreted
- It doesn't encourage good practices by itself
- Manage wisely your assumptions

These ideas apply to other languages too.

# Interface of a Unix command

- Inputs:

	* Arguments
	* Standard input
	* Environment
  
- Outputs:

    * Return value
    * Standard output
    * Standard error

#  Arguments
  Handle your arguments wisely:
  
-        Return non-zero upon bad arguments
-        Don't ignore unknown arguments
-        Support `-h | --help`, stdout
-        Support `-v | --version`, stdout
-        Non-destructive default action when called without parameters 
-		 `--dry`

# Argument parsing 

If possible define your options in structures (arrays).

```
section Files 
option INPUT input,i "Set input file"
option OUTPUT output,o "Set output file"
```

- Automatic help generation
- Easy bash-completion support
- Easier internationalization

# stdin. Console orientation

Don't assume X11 or the console. 
Define functions such as {showMessage, showError,die}.
Then you can quickly switch to a GUI. (zenity, xmessage...)

```
getString() {
	local prompt="$1"
	local default="$2"
    if [ -n "${DISPLAY:-}" ] && which zenity >& /dev/null
    then
		zenity --entry --text="$prompt"
	else if tty -s     ## Checks whether stdin is a tty
		read -p "$prompt: "
		echo "$REPLY"
	else
		echo "$default"
	fi
}

serverHost=$(getString "Serverhost" "localhost")
```


# Return value. Error handling

Pessimism rules. Don't assume everything will go well:

- return zero iff success
- set -e because:
	- you avoid the need to "`if ! cmd ; ...`" in every line
	- any failing line most probably means the rest of your script is senseless.
    - shows the actual error ASAP.  The message will be more meaningful.
    
# Return value. Error handling (2) 

- set -u: undefined variables most probably mean misspelled names or missing arguments.
- set -o pipefail

# `set -eu` pitfalls 

- Problem detecting if a variable is defined (trying to expand it would fail). 

```
if [ -z "$VAR" ]          ##breaks on -u
then 
    warn "VAR is not defined" 
fi   
```

Solution: Use `${VAR:-}`

```
if [ ${VAR:-} == "" ]
then 
	warn "VAR is not defined" 
fi	
```

Ignoring errors (~ignoring exceptions)

```
program_that_may_fail || true 
```

```
program || die "Cannot run program"
```
# -eu Example

```
#! /bin/bash 

set -eu 

inputfile=/dev/stdin
verbose=false

while getopts "i:o:v" opt; do
  case $opt in
    i) inputfile=$OPTARG  ;;
    o) outputfile=$OPTARG ;;
    v) verbose=true ;;
    \?) echo "Invalid option: -$OPTARG" >&2 ;;
  esac
done
$verbose && set -x
echo From $inputfile to $outputfile
```

```
$ ./test.sh 
./test.sh: line 15: outputfile: unbound variable
```


# stderr. Logging

- Keep your stdout clean; complain to stderr.  This will save you some grief the day you want to use your script in a pipeline. 
- Define "die".

```
function log() { echo "$*" >&2 ; }
function die() { echo "$*" >&2 ; exit 1; }
```

# Hyper-verbosity

If you find yourself running your applications with `>& /dev/null`, consider improving them so that they are not so verbose by default.  Otherwise:

- You miss detailed error messages
- You waste time composing and writing the messages
- Some programs offer silent modes: 
	- `grep -q`
	- `tty -s` (checks tty availability)


#   Current directory 

- Assumptions about current directory must be well justified.  
- Ideally scripts should be callable from anywhere.
- Worry when you see yourself writing `/home/...` even temporarily. 
	- Use something related to the current directory instead.  
	- Even references to $HOME are discouraged.

#    Be atomic

- Don't generate files in-place, but to a temp file, and then rename.

- Trap EXIT so that a SIGINT will cleanup as much as possible.
- Untrap when finished

- `lockfile` mutual exclusion
- task-spooler


```
#! /bin/bash 

TARGET_DIR=$1 
trap "rm -rf $TARGET_DIR" EXIT  ## FIXME: no space-transparent

construct $TARGET_DIR

trap EXIT    ## don't remove the target directory from this point
```

Challenge: Cleanly combining multiple cleanup procedures

# Task spooler 

```
$ tsp mv dirA dest
$ tsp mv dirB dest 
$ tsp 
ID   State      Output               E-Level  Times(r/u/s)   Command [run=0/1]
0    finished   /tmp/ts-out.exiT0X   0        0.00/0.00/0.00 mv dirA dest
1    finished   /tmp/ts-out.Flz2vB   0        0.00/0.00/0.00 mv dirB dest
```

#    Be functional - use make

...sometimes.

If you are building files that are derived from other files, don't make (just) an imperative script. A make-file might be more appropriate.  Advantages:

-        An explicit declaration of file dependencies instead of a topologically sorted imperative list.
-        Parallelism for free.
-        Automatic removal of target file if the process fails.

#  Missing tools

  Don't assume you have all the tools you need.  Since scripts perform lazy parsing and invoking, may well happen that the needed tools are not available.
    
-        If they are not common: `which` for them at the beginning and even suggest the package to install.
-        If you need a concrete version (for example of the JVM), test by invoking it with "-version".  


``` 

function require() { for p in "$@" ; do which "$p" > /dev/null || die "$p is not available" ; done ; }

require lame nodejs
```
#    Keep them  short 

If you need to perform many relatively independent tasks (such as in an installer)

- create multiple files as a kind of libraries and source them 

- split them into different files and `run-parts` that directory.  

	- `--exit-on-failure`
	- Pitfall: it is not trivial to pass variables from one subtask to another.
	
#    Don't fork unless needed

- Waste of time
- Waste of space in the process table
- Problems with signalling. SIGKILL, SIGTERM 
- Scripts that just set some variables and then run another program should not simply execute it (fork+exec) but just exec it (thus avoiding one process in the system).
- However: You need to fork+exec for cleaning up

#    Be space-transparent. 

- Double-quote everything.  
	- For example find your dependencies with `"$(dirname "$0")"`
- ```find -print0 | xargs -0r``` 

# Parsing output

- Locale assumptions
	- Don't assume a certain locale. 
	- If needed, force it: export LANG=C.UTF-8

```
## Remove files if they exist in $DIR2

find -type f -print0 |
	xargs -0r md5sum  |
	( cd "$DIR2" && md5sum -c )  | 
	sed -n 's/: OK$//p' | 
	tr '\n' '\0' | 
	xargs -0r rm -v 
```
- Don't parse ls's output. *ls* was meant to be human readable, not machine readable. <http://mywiki.wooledge.org/ParsingLs>

#  Shutdown requests 

- Politely ask processes for termination. Programs should die gracefully.
- Do not SIGKILL things just to make sure they will die. 

- Risks:
	-            The program can corrupt its persisted state
	-        SIGKILLing programs hides their failure to properly shut down, which could bring problems later
	-       Even simple programs such an IRC client will show "Connection reset by peer" quit message instead of "Quit: Leaving".

# Robust start

- Don't wait forever for servers to start.  Set a timeout.  
- Try to check as much as possible that the server has started (open ports ...)

- Servers are much more robust when they perform the fork themselves than when we launch them in background. (Important if you are implementing a server yourself)

```
myservice & 
SERVICE_PID=$!
trap "kill $SERVICE_PID" EXIT
sleep 1
if ! ps $SERVICE_PID
then
	die "Server died too quickly"
fi
```

# Robust start - checking an open port

```
myservice & 
SERVICE_PID=$!
trap "kill $SERVICE_PID" EXIT

while ! nc -z  localhost 1234     ##netcat's zero-I/O
then 
	if ! kill -0 $SERVICE_PID 
	then
		die "Server died prematurely"
	fi
	echo "Waiting for the server to open up the port"
	sleep 1
done

```
	
#  Robust termination 
	
- Signal it once to exit gracefully then after a while SIGKILL it and show a warning in case it had not died in first instance: you would have some issue there.
- Always wait programs for a while for them to free up bound sockets. 	

```
if kill $SERVER_PID
then 	
    sleep 1
    if kill -KILL $SERVER_PIF   
    then 
		warn "Server didn't die in time"; sleep 1 ; 
    fi
else
	warn "Server was already dead"
fi	
```    
	
	

	

# Daemonize non-daemoniac processes

Easy way to keep your non-daemon-like processes up.

daemon -r -- /usr/local/bin/myservice.sh

- Respawning (limited retrials allowed)
- Redirections
- chdir
- Saving the PID for later termination



# Empty sets

Don't assume non-empty sets:

- Don't "for in \*" (will expand to * if no files), unless $nullglob$.

```
shopt -s nullglob
```

```
$ echo *.avi
*.avi
$ shopt -s nullglob
$ echo *.avi
<empty>
```

- Don't xargs without -r (it is probably not worth to run your program with no arguments). (ls, rm, ...)

#  You're not alone in the CPU

Don't assume the amount of available cores. If at all, use "\$(nproc)". 

```
make -j$(nproc) -l$(nproc)
```

```
make -j$(nproc) -l$(nproc) ${MAKEFLAGS:-}   # Makeflags has priority
```
#   You're not alone in the disk

- Scripts should not use global directories anchored in /tmp.  
- Concurrent executions (in a CI machine for example) will collide. 
- If possible, a directory inside the project root (if such concept exists) should be used.

#  Temporaries 

  Create temporary files and directories wisely. 
  
-        Don't use a single directory with a certain name in /tmp. Risks:
     -       collisions among different executions. 
     -       Permissions problems in multiuser. 
     -       Exposure to malicious attacks.
     -       No direct support for alternative temporary partitions (mktemp honors \$TPMDIR)
     
# Secure temps
     

- For directories: 

```
TMPD=$(mktemp -d) ; trap "rm -rf $TMPD" EXIT
```
- For files: 

```
TMPF=$(mktemp ) ; trap "rm -f $TMPD" EXIT
```
     
# Abusing temporaries
     
-        Don't use temporary files unless needed.  "Better than cleaning is not get dirty"
     -       Use pipelines
     -       For multiple outputs, use process replacement: source | tee >(sink1) | sink2
     
# Don't abuse cats

-     `cat file | program` vs `program < file`:
	- extra needless process
	- prevents program from memory-mapping the file

# Nothing is forever	
	
-     Avoid `while true` if a real check is available:
	- `while ps $SERVER1 && ps $SERVER2`
	- `while nc -z localhost $SERVER_PORT`
	- `while wget -qO /dev/null http://localhost:8080/check`

# `-- "$@"`

- Make your scripts freely parametrizable with "$@" if possible. 

```
mplayer-high-prio.sh:
#! /bin/bash 

set -eu 

sudo ionice mplayer "$@"
```

- Avoided risk: This will save you the risk of ad-hoc modifying the script and then forget.

#   Passwords

- Don't keep passwords in your scripts. 
- Risk: Leaking passwords when sharing or uploading scripts. 
- Tip: Save passwords to something like `"$(dirname "$0")"` or ~/.myapp.conf and source it

# && chaining    

Chain with && commands meant to be chained. 

```
sudo apt-get install package
package ...
```

- pasting mechanism is stupid
- if sudo or apt-get want some input, they will get "package", which was meant as an input to bash, and not to them
- all commands will be processed regardless of failures

vs

```
sudo apt-get install package && 
package ...
```

Ctrl-X Ctrl-E opens an editor in bash
```

# Modules 

```
#! /bin/bash 

set -eu 

source "$(dirname "$0")"/common_funcs.sh
```

# Respect user preferences

- xdg-open
- `x-www-open`
- `$VISUAL` 


# `#! /bin/bash`

$/bin/sh$ will fail in a machine with an alternative shell by default

dash is faster. Use it if possible. Remove bashisms.  checkbashisms.

# shcov

Code coverage in shell!

Because testing matters, right? ;) 

# Syntax check tools

- Overall checks:

  - checkshell

-  Bashisms: checkbashisms 

#    Don't abuse bash

... if other languages are more convenient:

- to handle socket connections
- to handle signals
- to do intensive string manipulation
- to do intensive CPU 

- Shell script should simply glue things together.

- Migrate to python
