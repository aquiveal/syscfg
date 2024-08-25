# Define the rclone command and parameters
$rcloneCommand = "rclone"
$rcloneArguments = "mount aquiveal-homelab-rwe3:pbs-reti-bucket C:\Users\aquiv\Buckets\pbs-reti-bucket --vfs-cache-mode writes"

# Start the rclone process in the background with a hidden window
Start-Process -FilePath $rcloneCommand -ArgumentList $rcloneArguments -WindowStyle Hidden

# Optionally, you can output a message to indicate that the process has started
Write-Output "rclone mount process started in the background."