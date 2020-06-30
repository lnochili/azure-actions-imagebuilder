# Github Action for Azure VM Image Builder  
Current action version: v0

## V0 Design Proposal
This actions aims at making it easier for customers to get started with the first step in the journey of VM deployments - creating custom VM images and distributing them. This action is designed to make it easier for customers to use Azure Image Builder service in CI/CD pipelines. It takes the artifacts the are built in a workflow, injects them into the base VM image and then runs the user defined customizer that can install, configure your application and OS while providing end to end traceability. 
<br>You can learn more about the enterprise scenarios, Azure Image Builder Service and other literature [here](https://microsoft-my.sharepoint.com/:w:/g/personal/lanochil_microsoft_com1/EUcpYCvGNR5Flyv58LpFoNcBGSTtnfqUW8yK7niO7zHk0w?CID=D26F4BF9-9C73-4488-880B-EA8477F98F01&wdLOR=c96D3495D-A4D0-4F20-8EA9-68B4D097277A)

 
### Prerequisites
* You must have access to a Github account or project, in which you have permissions to create a Github workflow 
* You must have an Azure Subscription with contributor permission to Azure Resource Groups of the source image and distributor images (AIB service intends to change authorization to User identity model in future and we need to investigate it before implementation)

#### Register and enable Azure features, as per below:

```bash
az feature register --namespace Microsoft.VirtualMachineImages --name VirtualMachineTemplatePreview
az feature show --namespace Microsoft.VirtualMachineImages --name VirtualMachineTemplatePreview | grep state
```
#### Register and enable for shared image gallery (if used in action)

```az feature register --namespace Microsoft.Compute --name GalleryPreview ```

Wait until it shows the feature state as "registered"

#### Check if your subscription is registered for the providers
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
### Assumptions
We assume that prior to running the action for Azure Image Builder, the user would have 
1. Logged into azure using [azure login action](https://github.com/Azure/login)
2. Downloaded all required artifacts to the default current working directory potentially using [download artifact action](https://github.com/actions/download-artifact#download-artifact-v2)
```yaml
      #Checkout action, if required
        - name: 'Checkout Github Action'
          uses: actions/checkout@master
      #Download the build artifacts
        - name: 'download build artifacts'
          uses: actions/download-artifacts@v2
            with:
              name: example_azure_imagebuilder
      #Required Azure Authentiation Action
        - name: azure authentication
          uses: azure/login@v1
            with:
              creds: ${{ secrets.AZURE_CREDENTIALS }}
      
 ```
## GitHub action for Azure Image Builder  
The action begins now!!!

### Action Inputs
### General Inputs 
 
#### location (mandatory)
This is the Azure region in which the Image Builder will run and this is also the region where the source image is present.  Currently, there are only limited Azure regions where Azure Image builder service is available. Hence, The source image must be present in this location along with the Image builder service. If the location is not from [supported regions](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-overview#regions), then action should throw error. 
so for example, if you are using Shared Gallery Image or Managed Image as source image, the image must exist in this Azure region.  This value is mandatory so that the image building process shall run in the same region as the source image.  

#### resource-group-name (optional)
This is the Resource Group where the temporary Imagebuilder Template resource will be created. This input is optional if the Login user/spn configured in Github Secrects has permissions to create new Resrouce Group.  The Action will create a new Resource Group to create and run the Image Builder resource.
The new Resource Group created will be unique which will be of the form : "rg_aib_action_XXXXXX" where xxxxx is a 5 digit random number.
The Azure region for the new resource group created will be set to the value of input variable 'location'.

#### imagebuilder-template-name (optional)
The name of the image builder template resource to be used for creating and running the Image builder service. 
This input is optional and by default, Action will use a unique name formed using a combination of resource-group-name and Github workflow Run number. The unique name of image builder template will be t_<ResourceGroup>_<os-type>_xxxxxxxx" where xxxxxxx will be a 10 digit random number. 

* If the input value is a path to a file name with .JSON extension. In this case, all other action inputs(except customizer) are ignored. The Github Action will assume the ARM template as the source for all inputs and user has ensured the values comply to standard ARM template schema for azure image builder.
* If the input value is a simple string without .JSON, it is used to create new Image builder template in Azure resource Group. The action will check and fails if imagebuilder template already exists. Currently, update/upgrade of image builder template is not supported and it requires to create a new image builder template whenever this action needs to run.

#### nowait-mode (optional)
The value is boolean which is used to determine whether to run the Image builder action in Asynchrnous mode or not.  The input is optional and by default it is set to 'false'. In future this can be expanded to use webhooks to trigger another workflow when the image building is complete in AIB service
  
#### build-timeout-in-minutes (optional)
The value is an integer which is used as timeout in minutes for running the image build and the input is optional.  By default the timeout value is set to 80 minutes, if the input value is not provided.

#### vm-profile ( Optional )
* [VM Size](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#vmprofile) - You can override the VM size, from the default value i.e. *Standard_D1_v2*. You may set to a different VM size to reduce total customization time, or to use specific VM sizes, such as GPU / HPC.

### Source Inputs
#### source-image-type (optional)   
The source image type that is being used for creating the custom image and should be set to one of three types supported:
[ PlatformImage | SharedGalleryImage | ManagedImage ]  

By default, The input is optional and is set to 'PlatformImage' type.

#### source-os-type: (mandatory)
This should be set to one of two OS types supported:  [ linux | windows ]. This information will also be used in the customization section to determine the default directory for dowloaded artifacts.

#### source-image (mandatory)
The value of source-image must be set to one of the Operating systems supported by Azure Image Builder. Apart from the Platform images from Azure Market place, You can choose from existing custom images that are Managed Images or image versions in Shared Image Gallery. This source-image value is mandatory and source image should be present in the Azure region set in the input value of 'location'.

 * If the image-type is PlatformImage, the value of source image will be the urn of image which is an output of 
 ```az vm image list   or az vm image show 
    format - [ "publisher:offer:sku:version" ] if Source Image Type is PlatformImage; Example:  [ "Ubuntu:Canonical:18.04-LTS:latest" ] 
 ```
 * if the image-type is Managed Image - You need to pass in the resourceId of the source image, for example:
```
/subscriptions/<subscriptionID>/resourceGroups/<rgName>/providers/Microsoft.Compute/images/<imageName>
```
 * If the image-type is SharedGalleryImage - You need to pass in the resourceId of the image version for example:
```
/subscriptions/$subscriptionID/resourceGroups/$sigResourceGroup/providers/Microsoft.Compute/galleries/$sigName/images/$imageDefName/versions/<versionNumber> 
```
* Note: For Azure Marketplace Base Images, Image Builder defaults to use the 'latest' version of the supported OS's




### Customizer Inputs

In the first version of Github action,  we will support only specifying only one customizer.  This customizer can be an inline version for Shell or PowerShell types supported by AIB service. The values mentioned by user would be converted to equivalent json syntax for AIB template.


#### customizer-source(optional)
This takes the path to a directory or a file in the runner. By default, it points to the default download directory of the github runner. 

This action has been designed to inject Github Build artifacts into the image by adding required customizer. To ingest  build artifacts into the custom image, the github workflow is assumed to have downloaded necessary artifacts using methods like  github action 'actions/download-artifacts@v2'. This action would then upload these artifacts to a temp azure storage account which would be accessible to the AIB service.

Please note that this Github action adds the build artifacts customizer as the fist one in the list of customizers so that the build artifacts are made available for the user defined customizer to perform additional customizations.

#### customizer-destination(optional)
The default path of customizer-destination would depend on the OS defined in 'source-os-type' field.
##### *Windows:*
By default, The customizer scripts or Files are placed in a path relative to C:\. This value needs to be set to the path, if the path is other than C:\.
##### *Linux:*
By default, the customer scripts or files are placed in a path relative to '/tmp' directory. however, on many Linux OS's, on a reboot, the /tmp directory contents are deleted. So if you need these customizer scripts or files to persist in the image, you need to set customizer-destination to the absolute path where the Github action can copy the scripts or files. 

#### customizer-script (optional)
The customer can enter multi inline powershell or shell commands and use variables to point to directories inside the downloaded location.


#### customizer-windows-Update (optional) (applicable for Windows only)
The value is boolean and set to 'false' by default. This value is for Windows images only, the image builder will run Windows Update at the end of the customizations and also handle the reboots it requires.

Windows Update configuration is executed to install important and recommended Windows Updates, that are not preview:
```json
"customize": [
        {
            "type": "WindowsUpdate",
            "searchCriteria": "IsInstalled=0",
            "filters": [
                "exclude:$_.Title -like '*Preview*'",
                "include:$true"
                        ],
            "updateLimit": 20
        }
           ],
```
### Distributor Inputs
After the Image Builder builds the image, the same can be distributed in different formats and in different Azure regions. The Github action requires the following inputs to determine the details so that the image can be distributed. This Github action shall distribute the image as one of the distributor types supported in a single Run.

If no input values are set for distributor, Github action will default to distributing the image as ManagedImage in the same Resource Group and same Azure region in which the Azure Image Builder was run.

#### distributor-type: (optional)
The distributor-type determines the format in which the image is to be distributed. This action supports 3 formats/types supported,  namely,  ManagedImage | SharedGalleryImage | VHD.

By default, the value for distributor-type is set to ManagedImage.

#### dist-resource-id & dist-location: (optional)
* For distributor type SharedGalleryImage, both these values are mandatory. The dist-resource-id is used to create an image version under the image definition in Azure regions listed in dist-location.

   The Image Gallery and the Image Definition must already exist and the ResourceID provided is an existing Azure Resource. Eg: 
   
    ```
    dist-resource-id: /subscriptions/<subscriptionID>/resourceGroups/<rgName>/providers/Microsoft.Compute/galleries/<galleryName>/images/<imageDefName>
     
    dist-location: westus2, westcentralus  #set to one or more  Azure regions to which the image needs to be distributed/replicated.
     ```

* For distributor type  ManagedImage, dist-resource-id is mandatory and is used to create the Managed image resource with the specified imageName. By  default, the image will be created in the same Azure region as the template. 
[TODO] Can we do away with this by setting a default image name (mi_ which will be unique in the Azure region set in dist-location.  

The value of dist-resource-id needs to be set as given below:

    ```
    dist-resource-id: /subscriptions/<subscriptionID>/resourceGroups/<rgName>/providers/Microsoft.Compute/images/<imageName>
   
    dist-location: westus2  #set to one of the Azure region to which the Managed image needs to be distributed. 
    ```   


* For distributor type VHD:
    * You cannot pass any values to this, Image Builder will create the VHD and the Github action will emit the resource id of VHD as output variable. 

#### run-output-name: (optional)
Image Builder Template can be created once and can be run many times to create Shared Gallery Image Versions or to update the existing Managed Image. Every Image builder run is identified with a unique run id.  This input value is to be set if you would like to have a specific name to the run in order to query image template run status to get shared image version details.  
If the value is not set, this action will create unique run output id based on the image builder template and the Github Run Number of the action/workflow.

#### dist-image-tags: (optional)
The values set will be used to set the user defined tags on the custom image artifact created.  The user defined tag is set in the format for key:value pair.  If more than one tag is to be set, use comma to separate the tag values.
This input value is optional and Github action applies default tags even if customer does not provide values to this input.

```Default tags are:
 template-name: $imagebuilder-template-name
 image-os: $source-os-type
 image-type: $image-type
```
[TODO] add github tags for traceability.

### Action Outputs:
This Github action emits a set  of outputs the following outputs are set by the IB Action so that it can be used by the subsequent actions 

#### imagebuilder-run-status: 
This value of this output will be the value of Image builder Run status set to either "Succeeded" or "Failed" based on the runState returned by Azure Image Builder.

#### run-output-name:
Upon completion of the action, The action emits output value run-output-name which can be used to get the details of the Image Builder Run.  The run-output-name can also be used to query and get more details of run, namely artifactsURI.

#### custom-image-uri: 
Upon successful completion, The github action emits the URI or resource id of the Image distributed.  

#### webhook-uri: 
If the nowait-mode is set to 'true' while running this Github action, this output variable will be set to the webhook URI.

The webhook-uri can be queried by subsequent action that can give the status of Run.  Upon completion of Image Builder run, webhook shall emit the output variables as listed above. 


## How to Use this Github action
Here are few examples of how to use this Github action for Azure Image Builder with different input values.

### Github action with ARM template as input

The below example will take the ARM template as input for Image Builder, and creates an Managed Image in the west central US region. This workflow also injects the artifacts downloaded ( if any ), to the custom image under /tmp directory.

```yaml
#workflow using Image builder Action with ARM template
jobs:
  custom-image-uri: ""
  - job-image-builder :
#Image builder action with minimal inputs to build custom linux image as Managed Image  
      - name: 'Test Github action for Azure Image builder'
        uses: azure/azureimagebuilder@v0
        with:
          resource-group-name: 'aib_example_rg'
          location: 'westcentralus'
          image-builder-template-name: $GITHUB_WORKSPACE/Imagebuildertemplate.json
#Check and access the custom image         
      - name: 'echo Image URI if Image builder step succeeded'
        #Persist the output of run
        if: ${{ job-image-builder.outputs.imagebuilder-run-status }} 
        run: 
          cutom-image-uri= ${{ job-image-builder.outputs.custom-image-uri }}
          echo $cusom-image-uri
```

### Github action to publish custom image to Shared Image Gallery

The below example with minimal inputs, publishes theimage to Shared Imag Gallery with image versions in the westcentral US & west US2  regions. This workflow also injects the artifacts downloaded ( if any ), to the custom image under /tmp directory.
```yaml
name: Azure workflow to push custom image to Shared gallery
on:
  push:
    paths: 
      - master 
     # [ .github/workflows/aib_action_test_workflow.yml ]
#workflow using Image builder Action which takes Managed Image as source and Shared image gallery as distributor
jobs:
  custom-image-uri: ""
  job_1:
    name: Azure Image builder run 
    runs-on: ubuntu-latest
    steps:
      - name: 'Checkout Github Action'
        uses: actions/checkout@master   
      - name: 'Download build artifacts'
        uses: actions/download-artifacts@v2
      - name: azure authentication
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

#Image builder action with minimal inputs to build custom linux image as Managed Image  
      - name: 'Test Github action for Azure Image builder with Managed Image as Source'
        uses: azure/azureimagebuilder@v0
        with:
          resource-group-name: 'iblinuxgalleryrg'
          location: 'westus2'
          source-image: 'Ubuntu:Canonical:18.04-LTS:latest'
          source-os-type:: 'linux'
          source-image-type: 'ManagedImage'
          customizer-source:: $GITHUB_WORKSPACE/src/install.sh
          customizer-destination: /var/www/myapp
          imagebuilder-template-name: aib_managed_image_template
          build-timeout-in-minutes: 20 
   ########Distributor details #############
          dist-type: SharedGalleryImage  
          dist-resource-id: '/subscriptions/xxxxx-xxxx-xxxx/resourceGroups/XXX-SharedImageRG//providers/Microsoft.Compute/images/aib_linux_shared'
          dis-location: westus2, westcentralus
          runoutput-name: 'aib_sig_linux.ub18.04'
          artifactTags: "github-example: sig-distributor"
 
#Image builder action complete to build custom linux image with build artifacts with a ManagedImage as the source        
      - name: 'echo Image URI if Image builder step succeeded'
          #Persist the output of previous step
        if: ${{ success() }}
        run: 
          custom-image-uri = ${{ job_1.outputs.custom-image-uri }}
          echo $cusom-image-uri
 ```
 

### Github action to build custom image of Windows OS from a ManagedImage 
The below example with minimal inputs, creates a custom image of Windows OS from an existing Managed Image as base image, creates a VHD in the same region as the image builder. This workflow also injects the artifacts downloaded ( if any ), to the custom image under /tmp directory. After customising the image, it also updates with latest Windows updates excluing the ones that are in Preview. The output of this action run will set the custom image URI to the VHD in Azure Storage account. 

```yaml
name: Azure workflow test sample
on:
  push:
    paths: 
      - master 
     # [ .github/workflows/aib_action_test_workflow.yml ]
#workflow using Image builder Action
jobs:
  custom-image-uri: ""
  job_1:
    name: Azure Image builder run 
    runs-on: ubuntu-latest
    steps:
      - name: 'Checkout Github Action'
        uses: actions/checkout@master   
      - name: 'Download build artifacts'
        uses: actions/download-artifacts@v2
      - name: 'azure authentication'
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

#Image builder action with minimal inputs to build custom linux image as VHD from Managed Image
      - name: 'Test Github action for Azure Image builder'
        uses: azure/azureimagebuilder@v0
        with:
          resource-group-name: 'iblinuxgalleryrg'
          location: 'westcentralus'
          source-image: '/subscriptions/subscriptionId/resourceGroups/resourceGroupName/providers/Microsoft.Compute/images/imageName'
          source-image-type: 'ManagedImage' 
          source-os-type:: 'Windows'
          customizer-source:: $GITHUB_WORKSPACE/src/install.ps1
          customizer-destination: /var/www/myapp
          customizer-windows-update: 'true'
          dist-type: 'VHD'
          
#Image builder action complete to build custom linux image with build artifacts in the image        
      - name: 'echo Image URI if Image builder step succeeded'
          #Persist the output of run
        if: ${{ success() }}
        run: 
          cutom-image-uri= ${{ job_1.outputs.custom-image-uri }}
          echo $cusom-image-uri
 ```

### Github action to build custom image of Windows OS from a Shared Gallery Image
The below example workflow with this Github action for azure image builder, creates a custom image of Windows OS taking an existing Shared Gallery Image version as the source image. The below workflow creates a new image version in Shared Image Gallery and replicates the shared gallery image into the regions westcentralus and westus2. This workflow also injects the artifacts downloaded ( if any ), in to the custom image under /tmp directory. After customising the image, it also updates with latest Windows updates excluing the ones that are in Preview. The output of this action run will set the custom image URI to the VHD in Azure Storage account. 
```yaml
name: Azure workflow test sample
on:
  push:
    paths: 
      - master 
     # [ .github/workflows/aib_action_test_workflow.yml ]
#workflow using Image builder Action
jobs:
  custom-image-uri: ""
  job_1:
    name: Azure Image builder run 
    runs-on: ubuntu-latest
    steps:
      - name: 'Checkout Github Action'
        uses: actions/checkout@master   
      - name: 'Download build artifacts'
        uses: actions/download-artifacts@v2
      - name: 'azure authentication'
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

#Image builder action with minimal inputs to build custom linux image as VHD from Managed Image
      - name: 'Test Github action for Azure Image builder'
        uses: azure/azureimagebuilder@v0
        with:
          resource-group-name: 'iblinuxgalleryrg'
          location: 'westcentralus'
          source-image: '/subscriptions/<subscriptionId>/resourceGroups/<gallery-resource-group>/providers/Microsoft.Compute/galleries/<galleryname>/images/WindowsDataCenter2019R2'
          source-image-type: 'SharedGalleryImage' 
          source-os-type:: 'Windows'
          customizer-source:: $GITHUB_WORKSPACE/src/install.ps1
          customizer-destination: /var/www/myapp
          customizer-windows-update: 'true'
          dist-type: 'SharedGalleryImage'
          dist-location: 'westcentralus, westus2'
          dist-image: '/subscriptions/<subscriptionId>/resourceGroups/<gallery-resource-group>/providers/Microsoft.Compute/galleries/<galleryname>/images/WindowsDataCenter2019R2'
#Image builder action complete to build custom linux image with build artifacts in the image        
      - name: 'echo Image URI if Image builder step succeeded'
          #Persist the output of run
        if: ${{ success() }}
        run: 
          custom-image-uri= ${{ job_1.outputs.custom-image-uri }}
          echo $custom-image-uri
```

### Create a VM from published Shared Gallery Image Gallery:

Check the working github workflow here: [Deploy VM from SIG](https://github.com/raiyanalam/azureImageBuilderAction/blob/master/.github/workflows/create-vm-from-sig.yml)

```yaml
    - name: Deploy Azure VM from Shared Image Gallery
      uses: azure/CLI@v1
      with:
        azcliversion: 2.0.72
        inlineScript: |
          az account show                   
          subscriptionID=afc11291-9826-46be-b852-70349146ddf8
          sigResourceGroup=raiyan-rg2
          sigName=rai_sig_eastus
          imageDefName=rai_ubunut_packer_def
          location=eastus
          vmName=rai-vm-frm-sig
          adminUsername=moala
          adminPassword=${{ secrets.vm_pwd }}
          az vm create \
            --resource-group $sigResourceGroup \
            --name $vmName \
            --admin-username $adminUsername \
            --location $location \
            --image "/subscriptions/$subscriptionID/resourceGroups/$sigResourceGroup/providers/Microsoft.Compute/galleries/$sigName/images/$imageDefName/versions/latest" \
            --admin-password $adminPassword \


```
### Create a VMSS from published Shared Gallery Image Gallery:

Check the working github workflow here: 
[Deploy VMSS from SIG]: (https://github.com/raiyanalam/azureImageBuilderAction/blob/master/.github/workflows/create-new-vmss-from-sig.yml)

```yaml
  - name: Deploy Azure VM from Shared Image Gallery
    uses: azure/CLI@v1
    with:
      azcliversion: 2.0.72
      inlineScript: |
        az account show         
        subscriptionID=afc11291-9826-46be-b852-70349146ddf8          
        sigResourceGroup=raiyan-rg2
        sigName=rai_sig_eastus
        imageDefName=rai_ubunut_packer_def
        location=eastus
        vmssName=rai-vmss-frm-sig
        adminUsername=moala
        adminPassword=${{ secrets.vm_pwd }}
        az vmss create  --resource-group $sigResourceGroup --name $vmssName --instance-count 3 \
            --image "/subscriptions/$subscriptionID/resourceGroups/$sigResourceGroup/providers/Microsoft.Compute/galleries/$sigName/images/$imageDefName/versions/latest"  \
            --admin-username $adminUsername  --location $location --admin-password $adminPassword
            
```
