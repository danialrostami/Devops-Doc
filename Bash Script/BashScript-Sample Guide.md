# Bash Scripting Language — Sample Guide

This document introduces the Bash scripting language using a practical, well-documented sample script. It explains common Bash concepts with short examples and clear notes, making it suitable for beginners, self-learning, or quick reference.

---

## Table of Contents
1. [Hello World](#1-hello-world)
2. [Variables](#2-variables)
3. [Functions](#3-functions)
4. [Arithmetic Operations](#4-arithmetic-operations)
5. [Quoting: Single vs Double](#5-quoting-single-vs-double)
6. [User Input: `read`](#6-user-input-read)
7. [Menus: `select`](#7-menus-select)
8. [File and Directory Tests](#8-file-and-directory-tests)
9. [Loops: `while`, `for`, `until`](#9-loops-while-for-until)
10. [Conditional Statements: `if`, `elif`, `else`](#10-conditional-statements-if-elif-else)
11. [Here Documents](#11-here-documents)
12. [Case Statements](#12-case-statements)
13. [Arrays](#13-arrays)
14. [Text Editing with `sed`](#14-text-editing-with-sed)
15. [Disk Space with `df`](#15-disk-space-with-df)
16. [Text Processing with `awk`](#16-text-processing-with-awk)
17. [Field Extraction with `cut`](#17-field-extraction-with-cut)

---

## 1. Hello World

```bash
echo "Hello bash"
```

Prints a simple message to the terminal.

---

## 2. Variables

Variables store values for later use.

```bash
USER=Danial
echo "hello ${USER}"
```

### Global vs local scope

```bash
USER=Danial

echo "hello ${USER}"  # Danial
```

A variable defined outside a function is global by default.

---

## 3. Functions

Functions let you group commands into reusable blocks.

### Basic syntax

```bash
fname() {
  echo "Hello from function"
}

fname
```

### Function and variable scope

```bash
USER=Danial

fname() {
  local USER=ali
  echo "hello ${USER}"
}

echo "hello ${USER}"   # Danial
fname                    # ali
echo "hello ${USER}"   # Danial
```

### Function with arguments

```bash
greet() {
  echo "Hello, $1"
}

greet "Danial"
```

- `$1` = first argument
- `$2` = second argument
- `$@` = all arguments

### Return status

```bash
check_number() {
  if [[ $1 -gt 10 ]]; then
    return 0
  else
    return 1
  fi
}

check_number 15
echo $?
```

In Bash, `return` is used for an exit status, not for returning text. To return text-like output, print it with `echo` and capture it if needed.

---

## 4. Arithmetic Operations

```bash
echo $((20+5))
echo $((20-5))
echo $((20/5))
echo $((20*5))
echo $((5**3))
```

Examples of integer arithmetic in Bash.

---

## 5. Quoting: Single vs Double

```bash
echo "There is no * in my path: $PATH"
echo 'There is no * in my path: $PATH'
```

- **Double quotes** expand variables such as `$PATH`
- **Single quotes** keep the text literal

---

## 6. User Input: `read`

### Read input from the user

```bash
read -p "Enter your age: " AGE
echo "your age: $AGE"
```

### Read input with a default value

```bash
read -p "Enter your age [37]: " AGE
AGE=${AGE:-37}
echo "$AGE"
```

If the user enters nothing, `AGE` becomes `37`.

---

## 7. Menus: `select`

```bash
select OS_NAME in debian ubuntu arch alpine busybox
do
  echo "Your OS: $OS_NAME"
  break
done
```

Creates a numbered menu and stores the selected value in `OS_NAME`.

---

## 8. File and Directory Tests

### Check whether a directory exists

```bash
DIR_PATH=./test
[ -d "$DIR_PATH" ] && echo "Directory exists" || echo "Directory does not exist"
```

Quoting variables is a safer habit, especially when paths may contain spaces.

---

## 9. Loops: `while`, `for`, `until`

### `while` loop

```bash
x=1
while [ "$x" -le 5 ]
do
  echo "Welcome $x times"
  sleep 1
  x=$((x + 1))
done
```

### `for` loop with a range

```bash
for NUMBER in {1..3}
do
  echo "My Number: $NUMBER"
  sleep 1
done
```

### C-style `for` loop

```bash
for (( c=1; c<=5; c++ ))
do
  echo "Welcome $c times"
  sleep 1
done
```

### `until` loop

```bash
counter=0
until [ "$counter" -gt 5 ]
do
  echo "Counter: $counter"
  sleep 1
  ((counter++))
done
```

### Wait until a file exists

```bash
log_path="./log"
until [ -f "$log_path" ]
do
  echo "Waiting for the file to be created..."
  sleep 1
done
echo "The file exists. Proceeding..."
```

### Wait until a host becomes reachable

```bash
until ping -c1 www.google.com &>/dev/null
do
  echo "Waiting for www.google.com - network down?"
  sleep 1
done
echo "Ping successful! www.google.com is reachable."
```

---

## 10. Conditional Statements: `if`, `elif`, `else`

```bash
read -p "Enter a number: " VAR

if [[ $VAR -gt 10 ]]; then
  echo "The variable is greater than 10."
elif [[ $VAR -eq 10 ]]; then
  echo "The variable is equal to 10."
else
  echo "The variable is less than 10."
fi
```

Used for decision-making in Bash scripts.

---

## 11. Here Documents

```bash
cat << EOF > /tmp/test
These contents will be written to the file.
    This line is indented.
EOF
```

A here document lets you write multiple lines of text directly into a command or file.

---

## 12. Case Statements

### Basic `case` example

```bash
echo "What is your favorite operating system?"
read OS_NAME

case $OS_NAME in
  linux)
    echo "You love Linux? We do too!" ;;
  bsd)
    echo "BSD is a good system, too" ;;
  windows)
    echo "I do not like Windows" ;;
  *)
    echo "You should consider an open source system" ;;
esac
```

### Another `case` example with `date`

```bash
day=$(date +"%a")

case $day in
  Mon | Tue | Wed | Thu | Fri)
    echo "Today is a weekday" ;;
  Sat | Sun)
    echo "Today is the weekend" ;;
  *)
    echo "Date not recognized" ;;
esac
```

---

## 13. Arrays

```bash
array=(one two three four five six)

echo "${array[0]}"
echo "${array[1]}"
echo "${array[2]}"
echo "${array[3]}"
echo "${array[4]}"
echo "${array[5]}"
echo "${array[*]}"
```

### Loop through an array

```bash
number=${#array[@]}

for (( i=0; i<number; i++ )); do
  echo "${array[i]}"
done
```

### Useful array syntax

- Create an array: `array=(one two three)`
- Get length: `${#array[@]}`
- Get one element: `${array[0]}`
- Get all elements: `${array[@]}`

---

## 14. Text Editing with `sed`

### Simple replacement

```bash
echo "Bash Scripting Language" | sed 's/Bash/Perl/g'
```

### Create a sample file

```bash
cat <<EOF > /tmp/test.txt
Python is a very popular language.
Python is easy to use. Python is easy to learn.
Python is a cross-platform language
EOF
```

### Replacement examples

```bash
sed 's/Python/Perl/g'   /tmp/test.txt
sed '1 s/Python/Perl/g' /tmp/test.txt
sed '2 s/Python/Perl/g' /tmp/test.txt
sed '3 s/Python/Perl/g' /tmp/test.txt
sed 's/Python/Perl/2'   /tmp/test.txt
```

- Replace all matches in each line
- Replace only on a specific line
- Replace only the second match in a line

---

## 15. Disk Space with `df`

```bash
free=$(df --output=avail -h / | awk 'NR==2 {print $1}')
echo "$free"
```

Gets the available disk space for the root filesystem.

---

## 16. Text Processing with `awk`

### Create a sample file

```bash
cat <<EOF > /tmp/sample.txt
1) Amit     Physics   80
2) Rahul    Maths     90
3) Shyam    Biology   87
4) Kedar    English   85
5) Hari     History   89
EOF
```

### `awk` examples

```bash
awk '{print $0}' /tmp/sample.txt
awk '{print $3 "\t" $4}' /tmp/sample.txt
awk '{print $2 "\v" $4}' /tmp/sample.txt
awk '{print $1 "\t" $4}' /tmp/sample.txt
awk '/a/' /tmp/sample.txt
awk '/a/ {print $3 "\t" $4}' /tmp/sample.txt
awk '/a/{++cnt} END {print "Count = ", cnt}' /tmp/sample.txt
awk 'length($0) > 18' /tmp/sample.txt
```

### Notes

- `$0` means the entire line
- `$1`, `$2`, `$3` and so on mean fields
- `/a/` matches lines containing `a`
- `END` runs after all input is processed

---

## 17. Field Extraction with `cut`

```bash
cut -d: -f1,6 /etc/passwd
```

- `-d:` sets `:` as the delimiter
- `-f1,6` prints fields 1 and 6

A common use for this command is displaying usernames and home directories from `/etc/passwd`.

---
