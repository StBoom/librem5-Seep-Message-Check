case $1/$2 in
  pre/*)
    # Vor dem Schlafen: wakeup-check-pre.service starten
    ;;
  post/*)
    /usr/local/bin/wakeup-check.sh post
    ;;
esac
