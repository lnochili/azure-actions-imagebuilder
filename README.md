# Github Action for Azure VM Image Builder  
Current action version: v0

## V1 Design Purpose
This action is designed to take your build artifacts, and inject them into a VM image, so you can install, configure your application, and OS.
 
## Using the Github Action for Azure VM Image Builder
--- Visit https://github.com/marketplace 
--- Add the action for Azure VM Image Builder
 
## Prereqs
* You must have access to a Github account or project, in which you have permissions to create a Github workflow 
* You must have an Azure Subscription with contributor permission to Azure Resource Groups of the source image and distributor images  
* Register and enable Azure features, as per below:

```bash
az feature register --namespace Microsoft.VirtualMachineImages --name VirtualMachineTemplatePreview
az feature show --namespace Microsoft.VirtualMachineImages --name VirtualMachineTemplatePreview | grep state
```
# Register and enable for shared image gallery

```az feature register --namespace Microsoft.Compute --name GalleryPreview ```

Wait until it shows the feature state as "registered"

# check if your subscription is registered for the providers
```az provider show -n Microsoft.VirtualMachineImages | grep registrationState
az provider show -n Microsoft.Storage | grep registrationState
az provider show -n Microsoft.Compute | grep registrationState
az provider show -n Microsoft.KeyVault | grep registrationState
```

If shown not registered, run the commented out code below.
```bash
## az provider register -n Microsoft.VirtualMachineImages
## az provider register -n Microsoft.Storage
## az provider register -n Microsoft.Compute
## az provider register -n Microsoft.KeyVault
```
```bash
# create storage account and blob in resource group
subscriptionID=<INSERT YOUR SUBSCRIPTION ID HERE>
az account set -s $subscriptionID
strResourceGroup=<ResourceGroupName>
location=westus
scriptStorageAcc=aibstordot$(date +'%s')
az storage account create -n $scriptStorageAcc -g $strResourceGroup -l $location --sku Standard_LRS
```
## Create & configure the Github Workflow
1. Configure the Github Secret with name 'AZURE_CREDENTIALS' that will be used access Azure Subscription
2. Ensure that following github actions are added as steps to workflow that are to be run prior to running the action for Azure Image Builder
3. If the build artifacts are to be injected to the custom image, download the artifacts of specific build pipeline
```
      #Checkout action, if required
        - name: 'Checkout Github Action'
          uses: actions/checkout@master
      #Download the build artifacts
        - name: 'download build artifacts'
          uses: actions/download-artifacts@v1
            with:
              name: example_azure_imagebuilder
      #Required Azure Authentiation Action
        - name: azure authentication
          uses: azure/login@v1
            with:
              creds: ${{ secrets.AZURE_CREDENTIALS }}
      
 ```
## Add the Github action for Azure Image Builder 
The action begins now!!!
 
### Define the inputs 
 
#### resource-group-name (optional)
This is the Resource Group where the temporary Imagebuilder Template resource will be stored. This input is optional if the Login user/spn configured in Github Secrects has permissions to create new Resrouce Group.  The Action will create a new Resource Group to create and run the Image Builder resource.
  
As mentioned in Azure Image Builder docs, when creating a Image Builder template artifact, it creates an additional resource group, ‘IT_<DestinationResourceGroup>_<TemplateName>_ResourceId. This resource group is used to create teh temporary Azure resources required for running Image Building Process. 
* Azure Storage Account to store the image metadata, such as customizer scripts
* Azure resources for a Virtual Machine with Public IP. 
At the end of the aciton, these temporary resources shall be deleted when the Github action is configured to do so. 

#### location (optional)
   This is the Azure region in which the Image Builder will run, currently, there are only limited Azure regions where Azure Image builder service is available. The source images must be present in this location, so for example, if you are using Shared Gallery Image or Managed Image, the image must exist in that Azure region.
   The value is optional and will be set to the region of Resource Group Name supplied above.

#### imagebuilder-template-name (optional)
  The name of the image builder template resource to be used for creating and running the Image builder service. 
  This input is optional and by default, Action will use a unique name formed using a combination of resource-group-name and Github workflow Run number.
  If the input value is a path or file name containing .JSON extension, no more inputs are required and the input value is considered as  the ARM Template file to be used. The Github Action will consider the ARM template as source for all inputs.
  If the input value is a simple string, it is used to create & run the Image builder template resource in Azure resource Group.

#### nowait-mode (optional)
  The value is boolean which is used to determine whether to run the Image builder action in Asynchrnous mode or not.  The input is optional and by default it is set to 'false'
  
#### build-timeout-in-minutes (optional)
  The value is an integer which is used as timeout in minutes for running the image build and the input is optional.  By default the timeout value is set to 80 minutes, if the input value is not provided.
  
#### image-type (optional)   
  The source image type that is being used for creating the custom image. Possible values:
     PlatformImage or SharedGalleryImage or ManagedImage
  The input is optional and set to 'PlatformImage' by default, if the input value is provided.

#### source-image (mandatory)
The value of source-image must be set to one of the supported Image Builder OS's. Apart from the Platform images from Azure Market place, You can choose existing custom images in the same region as Image Builder is running.
 * If the image-type is PlatformImage, the value of source image will be the urn of image which is an output of 
 ```az vm image list   or az vm image show 
    format - { publisher:offer:sku:version } if Source Image Type is PlatformImage; Example:  {Ubuntu:Canonical:18.04-LTS:latest } 
 ```
 * if the image-type is Managed Image - You need to pass in the resourceId of the source image, for example:
```/subscriptions/<subscriptionID>/resourceGroups/<rgName>/providers/Microsoft.Compute/images/<imageName>
```
 * If the image-type is SharedGalleryImage - You need to pass in the resourceId of the image version for example:
```
/subscriptions/$subscriptionID/resourceGroups/$sigResourceGroup/providers/Microsoft.Compute/galleries/$sigName/images/$imageDefName/versions/<versionNumber> 
```
* Note: For Azure Marketplace Base Images, Image Builder defaults to use the 'latest' version of the supported OS's

### Customizer details

In the Initial version of Github action,  we are supporting two customerizer types, 'Shell', and 'PowerShell'. Depending on the OS, select with PowerShell, or Shell. The customizer scripts need to be either publicly accessible or part of the github repository.  Github action will upload the the customizer scripts from github repository so that the same can be run by Image Builder to customize the image. 
This action has been designed to inject Github Build artifacts into the image. To make this work, you will need to setup a Build workflow, and in the setup of the Release pipeline, you must add specifics of the repo of the build artifacts.
#### customizer-type (optional)
  The value must be set to one of the ' Shell | PowerShell | InLine | File '.  This input is optional and defaults to the type required to inject the build artifacts using the subsequent inputs on customizer.

#### customizer-source 
These values are required only if customizer type is declared as Shell or PowerShell. 
If the customizer-type is Shell or PowerShell, then the value must be set to the URI for customizer scripts where the URI is   publically accessible 
If the customizer-type is File, source value is set to the path (file/directory) in the Github repo, if it is differnt than the default Github build artifacts path. By default, the source value is set to default path of Github build artficats downloaded by workflow.

If the customizer-type is Inline, you can enter inline commands separated by commas.
#### customizer-destination
These values are required only if customizer type is declared as Shell or PowerShell or File.  The input is optional and set to default values depending on the OS of Image.
* Windows
By default, The customizer scripts or Files are placed in a path relative to C:\. This value needs to be set to the path, if the path is other than C:\.

* Linux
By default, the customer scripts or files are placed in a path relative to '/tmp' directory. however, on many Linux OS's, on a reboot, the /tmp directory contents are deleted. So if you need these customizer scripts or files to exist in the image, you must provide the absolute path so that the Github action will copy the scripts or files or directories. for example:

#### customizer-windows-Update (optional for Windows only)
 The value is boolean and set to 'false' by default. This value is for Windows images only, the image builder will run Windows Update at the end of the customizations and also handle the reboots it requires.

  Windows Update configuration is executed to install important and recommended Windows Updates, that are not preview:
```json
    "type": "WindowsUpdate",
    "searchCriteria": "IsInstalled=0",
    "filters": [
        "exclude:$_.Title -like '*Preview*'",
        "include:$true"
```
### Distributor Inputs
After the Image Builder builds the image, it can be distributed in different formats in different Azure regions. The Github action requires the following inputs to determine the same so that the image can be distributed. The Github action can distribute the image to one of three types of distributors supported in a single Run.
#### distributor-type:
There are 3 distributor types supported by this Github actionn namely  ManagedImage | SharedGalleryImage | VHD.
By default, the distributor type is set to ManagedImage.
#### dist-resource-id & dist-location: (manadatory)
* Managed Image ResourceID:
    ```bash
    /subscriptions/<subscriptionID>/resourceGroups/<rgName>/providers/Microsoft.Compute/images/<imageName>
   
    dist-location - set to one of the Azure region to which the Managed image needs to be distributed. 
    ```   
* Azure Shared Image Gallery - this MUST already exist!  
    * ResourceID: 
    ```bash
    /subscriptions/<subscriptionID>/resourceGroups/<rgName>/providers/Microsoft.Compute/galleries/<galleryName>/images/<imageDefName>
     
     dist-location - set to one or more  Azure regions to which the shared gallery image needs to be distributed.
      * dist-location : list of regions, comma separated, e.g. westus, eastus, centralus
      ```
* VHD
    * You cannot pass any values to this, Image Builder will create the VHD and the Github action will emit the resource id of VHD as output variable. 


### Optional Settings (to be defined)
* [VM Size](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#vmprofile) - You can override the VM size, from the default of *Standard_D1_v2*. You may do this to reduce total customization time, or because you want to create the images that depend on certain VM sizes, such as GPU / HPC etc.

## How it works
When you create the release workflow with a step or job that includes this Github action, it will:
1) Creates the Resource Group, distributor Resources and other input defaults, if does not exist already. 
2) Creates a container in the storage account, named 'imagebuilder-githubaction', it will zip and upload your build artifacts or customizer scripts from the github Repo, and create a SAS Token on the that zip file. 
3) Using the inputs values passed to the action or the default values defined by action, the Github action creates Builder Template resource, which will in include:
    * Create a template prefixed 't_<ResourceGroup>_<os-type>' 10 digit monotonic integer, if the imagebuilder-template-name is not set.  
    * Adding additional inLine customizers to move the build artifacts from default location to the customizer-destination on the image 
4) It then runs the Image Builder process, which will perform
    * The Image builder creates a temporary resource group with ‘'IT_<resource-group-name>_<imagebuilder-template-name>_xxxxxxxxxx' 10 digit monotonic integer. 
    * Creates a storage account in the above temporary resource group, transfers the artifacts zip or scripts to a container named 'shell'. Saves the packerizer details and the logs into different containers in the same storage acocunt. During the image builder run, you will see this in the release logs, whilst the build is running:
```bash
starting run template...
```
4) When the image build completes you will see the following:
```bash
2019-05-06T12:49:52.0558229Z starting run template...
2019-05-06T13:36:33.8863094Z run template:  Succeeded
2019-05-06T13:36:33.8867768Z getting runOutput for  SharedImage_distribute
2019-05-06T13:36:34.6652541Z ==============================================================================
2019-05-06T13:36:34.6652925Z ## task output variables ##
2019-05-06T13:36:34.6658728Z $(imageUri) =  /subscriptions/<subscriptionID>/resourceGroups/aibwinsig/providers/Microsoft.Compute/galleries/<XXsig>/images/<imagename>/versions/0.23760.13763
2019-05-06T13:36:34.6659989Z ==============================================================================
2019-05-06T13:36:34.6663500Z deleting template t_1557146959485...
2019-05-06T13:36:34.6673713Z deleting storage blob imagebuilder-vststask\webapp/18-1/webapp_1557146958741.zip
2019-05-06T13:36:34.9786039Z blob imagebuilder-vststask\webapp/18-1/webapp_1557146958741.zip is deleted
2019-05-06T13:38:37.4884068Z delete template:  Succeeded
```
The image template resource, and ‘'IT_<DestinationResourceGroup>_<TemplateName>' will be deleted.

5. Github action emits output varaibles listed below. You can take the '$(artifactsUri)'variable for use in the next task, or just take its value and build a VM.
6. 

## Output DevOps Variables
* Pub/offer/SKU/Version of the source marketplace image:
    * $(pirPublisher)
    * $(pirOffer)
    * $(pirSku)
    * $(pirVersion)
* Image URI - The ResourceID of the distributed image:
    * $(imageUri)
## FAQ
1. Can i use an existing image template i have already created, outside of DevOps?
No, but stay tuned!!

2. Can i specifiy the image template name?
No, we generate a unique template name, then destroy it after.

3. The image builder failed, how can i troubleshoot?
* If there is a build failure the DevOps task will not delete the staging resource group, this is so you can access the staging resource group, that contains the build customization log.
* You will see an error in the DevOps Log for the VM Image Builder task, and see the customization.log location, as per below:
![alt text](./devOpsTaskError.png "devOps Error")
* Review the [troubleshooting guide](https://github.com/danielsollondon/azvmimagebuilder/blob/master/troubleshootingaib.md) to see common issues and resolutions. 
* After investigating the failure, to delete the staging resource group, delete the Image Template Resource artifact, this is prefixed with 't_', and can be found in the DevOps task build log:

```text
...
Source for image:  { type: 'SharedImageVersion',
  imageVersionId: '/subscriptions/<subscriptionID>/resourceGroups/<rgName>/providers/Microsoft.Compute/galleries/<galleryName>/images/<imageDefName>/versions/<imgVersionNumber>' }
...
template name:  t_1556938436xxx
...
```
The Image Template Resource artifact will be in the resource group specified initially in the task, you just need to delete it. Note, if deleting via the Azure Portal, when in the resource group, select 'Show Hidden Types', to view the artifact.

* If you still see issues, raise a GitHub issue here.

## Next Steps
If you loved or hated Image Builder, please go to next steps to leave feedback, contact dev team, more documentation, or try more examples [here](../../quickquickstarts/nextSteps.md)]


