awk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}' /home/username/.bash_history* | grep -E 'mount|s3|gdrive'
