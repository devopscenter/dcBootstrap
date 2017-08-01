In order to begin the bootstrap process for new developers of a customer, there does
need to be some manual work.  One of the tasks is to create a set of keys that can be
used when RUN-ME-FIRST.sh is executed.  

- check the guidelines for you cloud provider on how to make authentication keys

- for AWS go to the AWS console and if not already created create an account for the
  customer.  Then create the main user and make note of the access key and the secret
  key. They will be placed into the .aws/credentials file in the steps below 

- determine the directory on the shared drive to put the dcBootstrap files
    - create the destination-dir in the shared drive location
- download the zipped tarball of the devops.center repository: dcBootstrap
    - execute

```
cd destination-dir
curl -L https://github.com/devopscenter/dcBootstrap/archive/master  | tar xf -
mv devopscenter\* dcBootstrap
```

- change to the directory that was just created 
- create a directory named: .aws

```
mkdir .aws
```

- change directory to .aws
- create the config file like this:

```
[profile default]
output = json
region = us-west-2
```

- and then the credentials file like this:

```
[default]
aws_access_key_id = PUT_YOUR_ACCESS_KEY_HERE
aws_secret_access_key = PUT_YOUR_SECRET_KEY_HERE
```

- NOTE: replace the PUT_YOUR_ACCESS_KEY_HERE with the access key you got from creating the set of keys
        replace the PUT_YOUR_SECRET_KEY_HERE with the secret key you got from creating the set of keys

- then you will need to tar .aws into a tarball
- NOTE: use the following name for the tarball as the RUN-ME-FIRST.sh will look specifically for this name
        AND, that it is not zipped but a regular tarball (this may change at some point in the future if we 
        can determine that every machine that RUN-ME-FIRST.sh gets run on will have the unzip supported in
        that machines version of tar.

- cd to the directory that has .aws in it

```
tar -cf bootstrap-aws.tar .aws
```

- once there then every developer can run RUN-ME-FIRST.sh from that directory and they will have been 
  bootstrapped with the devops.center framework


