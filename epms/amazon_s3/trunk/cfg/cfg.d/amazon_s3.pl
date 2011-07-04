# To Configure your Amazon Storage, please fill in the configuration fields below:
#
# Once done, please remove the comments '#' from the beginning of each line, save this file and then reload the repository config from the Admin screen.
# 

#$c->{plugins}->{"Storage::AmazonS3"}->{params}->{aws_bucket} = "...";
#$c->{plugins}->{"Storage::AmazonS3"}->{params}->{aws_access_key_id} = "...";
#$c->{plugins}->{"Storage::AmazonS3"}->{params}->{aws_secret_access_key} = "...";

$c->{plugins}{"Storage::AmazonS3"}{params}{disable} = 0;
