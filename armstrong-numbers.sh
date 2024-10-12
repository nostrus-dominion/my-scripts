#!/bin/bash

echo -n "Enter A Number: "
read -r n
arm=0
temp=$n
while [ "$n" -ne 0 ]; do
	r=$((n % 10))
	arm=$((arm + r * r * r))
	n=$((n / 10))
done
echo $arm
if [ $arm -eq "$temp" ]; then
	echo "Is An Armstrong Number"
else
	echo "Is NOT An Armstrong Number"
fi
