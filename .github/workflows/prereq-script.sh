#!/usr/bin/sh
                az role assignment create --assignee cf32a0cc-373c-47c9-9156-0db11f6a6dfc --role Contributor \
                    --scope /subscriptions/$creds.subscriptionId/resourceGroups/$env.distributorResourceGroup --debug
                az group create -n $env.distributor_resource_group -l $env.image_location --debug
                az sig create -g $env.distributor_resource_group  --gallery-name $env.image_gallery_name --debug
                az sig image-definition create -g $env.distributor_resource_group --gallery-name $env.image_gallery_name \
                  --gallery-image-definition $env.image_definiation --publisher $publisher --offer $offer  \
                      --sku $sku  --os-type $os_type --debug
