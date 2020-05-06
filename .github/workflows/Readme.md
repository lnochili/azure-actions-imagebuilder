## How to Use this Github action
Here are few examples of how to use this Github action for Azure Image Builder with different inputs:

### Github action with ARM template as input

The below example will take the ARM template as input for Image Builder, and creates an Managed Image in the west central US region. This workflow also injects the artifacts downloaded ( if any ), to the custom image under /tmp directory.

```#workflow using Image builder Action
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
```
name: Azure workflow test sample
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

```
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
The below example with minimal inputs, creates a custom image of Windows OS from an existing Image definition as base image, creates another image version and publishes to the same Shared Image Gallery. This workflow also injects the artifacts downloaded ( if any ), to the custom image under /tmp directory. After customising the image, it also updates with latest Windows updates excluing the ones that are in Preview. The output of this action run will set the custom image URI to the VHD in Azure Storage account.
