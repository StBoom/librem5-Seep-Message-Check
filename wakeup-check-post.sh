#!/bin/bash

case $1/$2 in
  pre/*)
    # Vor dem Schlafen (optional)
    ;;
  post/*)
    # Nach dem Aufwachen
    /usr/local/bin/wakeup-check.sh post
    ;;
