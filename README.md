# devops.center Bootstrap process

In order to begin the bootstrap process for new developers wanting to use the devops.center
development framwork, there does need to be some manual work.  This is done one time by a single main
developer.  This manual work will set up the initial logins to the cloud provider as well as keys to
bootstrap any other developer.  The steps on this page prior to running RUN-ME-FIRST.sh would only be
done one time and the results will be stored in a bootstrap tarball that can be used by subsequent 
developers.  

There is one required step to get a developer set up using the devops.center framework, and that is to
the RUN-ME-FIRST.sh script.  This will be placed in the shared diretory (ie, Google Drive/devops.center/dcBootstrap)
and when run will set up the developers environment with the basic set of configs.  It will also 
pull down the dcUtils repository that will provide the tools that will make it easier to work with the 
framework.

If the developer needs to have access to AWS then there is a second script that will need to be run that will
set up the AWS configuration for that user.  The script to run is createAWS-setup.sh and it is in dcUtils.

Note, they the developers would only run these scripts one time to set up their own personalized environment.

What follows are the steps that need to be done by the devops.center engineer with an admin that has been
designated fro the company.

- for AWS go to the AWS console and if not already created create an account for the
  customer.  
  
  Then create the main user (admin-dev with administrator priviledges) and make note of the access key and the secret
  key. They will be placed into the .aws/credentials file in the steps below 

  There is an important step to note, and that is determining the name that
  will be used for the PROFILE.  This name will be used to access AWS from the
  devops.center scripts.  Ususally, the PROFILE name is the name of the company or 
  division. References made through out the documenation for the devops.center tools
  will to this PROFILE name, so it needs to needs to be the same by all developers. 
  AWS will associate instances with that PROFILE, hence the devops.center scripts will
  need it too.  So, we define it here and it will go into the appropriate confiuration
  files. 
  
- NOTE: when creating the main user, there are two AWS groups that will need to be made one
  that will allow the developer's ssh keys (that will be generated by RUN-ME-FIRST.sh) to 
  be associated with their IAM user.  And, another that will be the group that the IAM 
  user that gets created for the developer will be associated with.  This group specifies 
  policies for accessing the instances.

  The first group is called:

```
public-key-transfer
```

  and it will need to the policy:

```
IAMUserSSHKeys
```

  The policy IAMUserSSHKeys will be used by the script to allow the ssh keys to be associated
  with the IAM user that is created.  The script will add the user to the group, transfer the
  keys, and then remove the user from the group.  The user doesn't need to remain in that group
  beyond transferring the ssh keys.

  The group that the developer's IAM user will be associated with should have the 
  name that will be used for the PROFILE (usually the company name or a working version of it) 
  followed by by -dev. 

```
customerName-dev
```

   And the policies are:

```
AmazonS3FullAccess
AmazonEC2FullAccess
```

- determine the directory on the shared drive (or someplace on your local system if there is only one
developer) to put the dcBootstrap files
    - assuming the destination-dir is not there, create it in the shared drive location
- download the zipped tarball of the devops.center repository: dcBootstrap
    - execute the following:

    ```
    cd baseSharedDirectory/customername/devops.center
    curl -L https://github.com/devopscenter/dcBootstrap/archive/master.tar.gz  | tar xzf -
    mv dcBoostrap-master dcBootstrap
    ```

- change to the directory that was just created 
- create a directory named: .aws

    ```
    mkdir .aws
    ```

- change directory to .aws
- create the config file like this (NOTE: use the value you will assign to the PROFILE in
  place of the word default):

    ```
    [profile default]
    output = json
    region = us-west-2
    ```

- and then the credentials file like this (NOTE: use the value you will assign to 
  the PROFILE in place of the word default):

    ```
    [default]
    aws_access_key_id = PUT_YOUR_ACCESS_KEY_HERE
    aws_secret_access_key = PUT_YOUR_SECRET_KEY_HERE
    ```

- NOTE: replace the PUT_YOUR_ACCESS_KEY_HERE with the access key you got from creating the set of keys

- then you will need to tar .aws into a tarball
- NOTE: use the following name for the tarball as the RUN-ME-FIRST.sh will look specifically for this name
        AND, that it is not zipped but a regular tarball (this may change at some point in the future if we 
        can determine that every machine that RUN-ME-FIRST.sh gets run on will have the unzip supported in
        that machines version of tar.

- cd to the directory that has the .aws direcotry in it (don't be inside .aws, but up one directory)

    ```
    tar -cf bootstrap-aws.tar .aws
    ```

- before RUN-ME-FIRST.sh is executed it is possible to provide some common (to the customer) defaults to
  the questions that are asked in the RUN-ME-FIRST.sh script.  There is a file, init.conf, in the dcBootstrap
  directory that you can edit to give default values that the user can then just hit return to accept.  This
  would make for less typing that each user would have to make and could provide a bit of standardization 
  for development.  However, these values can still be overwritten when RUN-ME-FIRST.sh is run, as they are 
  more like suggestions.

- after completion every developer can run RUN-ME-FIRST.sh from that directory and they will have been 
  bootstrapped with the devops.center framework

- change directory to the directory that has the RUN-ME-FIRST.sh script and execute it:

    ```
    ./RUN-ME-FIRST.sh
    ```
    


