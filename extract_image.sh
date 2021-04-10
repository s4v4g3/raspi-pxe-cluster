#!/bin/bash

mkdir -p /work/root
./7zz x -oboot ./0.fat
mount -o ro,noload 1.img /work/root
mkdir -p /work/output/root
cp -a /work/root/* /work/output/root/
cp -a /work/boot/* /work/output/root/boot/


