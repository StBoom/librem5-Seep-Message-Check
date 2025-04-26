case $1/$2 in
  pre/*)
    # Vor dem Schlafen: wakeup-check-pre.service starten
    systemctl start wakeup-check-pre.service
    ;;
  post/*)
    # ... (restlicher Code wie oben)
    ;;
esac
