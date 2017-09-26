# devops.center Bootstrap process

In order to begin the bootstrap process for new developers wanting to use the devops.center
development framwork, there does need to be some manual work.  This is done one time by a single main
developer.  This manual work will set up the initial logins to the cloud provider as well as keys to
bootstrap any other developer.  The steps on this page prior to running RUN-ME-FIRST.sh would only be
done one time and the results will be stored in a bootstrap tarball that can be used by subsequent 
developers.  Then, all that needs to be done by other developers, is to have access to the directory that
has the RUN-ME-FIRST.sh script and execute it. 

    NOTE: The developers other than the first one will have their AWS keys created for them that will be
     assoicated with an IAM user (for AWS).  These keys will be put alongside any other keys in the
     .aws/config and .aws/credentials associated with the customer name that is given when RUN-ME-FIRST.sh
     is executed.

- One of the tasks is to create a set of key/value pairs that can be used when RUN-ME-FIRST.sh is executed.  

    - check the guidelines for you cloud provider on how to make authentication keys

    - For AWS go to the AWS console and if not already created create an account.
      Then create the main user and make note of the access key and the secret
      key. They will be placed into the .aws/credentials file in the steps below 

- determine the directory on the shared drive (or someplace on your local system if there is only one
developer) to put the dcBootstrap files
    - assuming the destination-dir is not there, create it in the shared drive location
- download the zipped tarball of the devops.center repository: dcBootstrap
    - execute the following:

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
- create the config file (using your favorite editor) to look like this:

    ```
    [profile default]
    output = json
    region = us-west-2
    ```

- and then the credentials file should look like this:

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

- cd to the directory that has .aws in it

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


