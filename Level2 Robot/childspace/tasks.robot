*** Settings ***
Documentation       Orders robots from RobotSpareBin Industries Inc.
...                 Saves the order HTML receipt as a PDF file.
...                 Saves the screenshot of the ordered robot.
...                 Embeds the screenshot of the robot to the PDF receipt.
...                 Creates ZIP archive of the receipts and the images.

Library           RPA.Browser.Selenium        auto_close=${FALSE}
Library           RPA.HTTP
Library           RPA.Tables
Library           RPA.PDF
Library           RPA.Archive
Library           Collections
Library           RPA.Robocloud.Secrets
Library           OperatingSystem

*** Variables ***
${url}            https://robotsparebinindustries.com/#/robot-order

${img_folder}     ${CURDIR}${/}image_files
${pdf_folder}     ${CURDIR}${/}pdf_files
${output_folder}  ${CURDIR}${/}outputs

${orders_file}    ${CURDIR}${/}orders.csv
${zip_file}       ${output_folder}${/}pdf_archive.zip
${csv_url}        https://robotsparebinindustries.com/orders.csv


*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    Directory Cleanup
    Open the robot order website
    

    ${orders}=    Get Orders

    FOR     ${row}     IN     @{orders}
            Close the annoying modal
            Fill the form     ${row}
            Wait Until Keyword Succeeds     10x     2s    Preview the robot
            Wait Until Keyword Succeeds     10x     2s    Submit The Order
            ${orderid}  ${img_filename}=    Take a screenshot of the robot
            ${pdf_filename}=                Store the receipt as a PDF file    ORDER_NUMBER=${order_id}
            Embed the robot screenshot to the receipt PDF file     IMG_FILE=${img_filename}       PDF_FILE=${pdf_filename}       
            Go to order another robot
    END
    
    Create a ZIP file of the receipts

    Log Out And Close The Browser
   

 

*** Keywords ***
Open the robot order website
    Open Available Browser    ${url}

Directory Cleanup
    Log To console      Cleaning up content from previous test runs

    # The archive command will not create this automatically so we need to ensure that the directory is there
    # Create Directory will not give us an error if the directory already exists.
    Create Directory    ${output_folder}
    Create Directory    ${img_folder}
    Create Directory    ${pdf_folder}

    Empty Directory     ${img_folder}
    Empty Directory     ${pdf_folder}
    Empty Directory     ${output_folder}    
   

Get orders
    Download      url=${csv_url}         target_file=${orders_file}    overwrite=True
    ${table}=     Read table from CSV     path=${orders_file}
    [Return]      ${table}

Close the annoying modal 
     Set Local Variable              ${btn_ok}        //*[@id="root"]/div/div[2]/div/div/div/div/div/button[1]
     Wait And Click Button           ${btn_ok}    

Fill the form
    [Arguments]     ${myrow}

    Set Local Variable    ${order_no}   ${myrow}[Order number]
    Set Local Variable    ${head}       ${myrow}[Head]
    Set Local Variable    ${body}       ${myrow}[Body]
    Set Local Variable    ${legs}       ${myrow}[Legs]
    Set Local Variable    ${address}    ${myrow}[Address]

    Set Local Variable      ${input_head}       //*[@id="head"]
    Set Local Variable      ${input_body}       body
    Set Local Variable      ${input_legs}       xpath://html/body/div/div/div[1]/div/div[1]/form/div[3]/input
    Set Local Variable      ${input_address}    //*[@id="address"]
    Set Local Variable      ${btn_preview}      //*[@id="preview"]
    Set Local Variable      ${btn_order}        //*[@id="order"]
    Set Local Variable      ${img_preview}      //*[@id="robot-preview-image"]


    Select From List By Value       ${input_head}           ${head}

    Select Radio Button             ${input_body}           ${body}

    Input Text                      ${input_legs}           ${legs}
    
    Input Text                      ${input_address}        ${address}

Preview the robot
    Set Local Variable              ${btn_preview}      //*[@id="preview"]
    Set Local Variable              ${img_preview}      //*[@id="robot-preview-image"]
    Click Button                    ${btn_preview}
    Wait Until Element Is Visible   ${img_preview}

Submit the order
    Set Local Variable              ${btn_order}        //*[@id="order"]
    Set Local Variable              ${lbl_receipt}      //*[@id="receipt"]
    Click button                    ${btn_order}
    Page Should Contain Element     ${lbl_receipt}

Take a screenshot of the robot
    # Define local variables for the UI elements
    Set Local Variable      ${lbl_orderid}      xpath://html/body/div/div/div[1]/div/div[1]/div/div/p[1]
    Set Local Variable      ${img_robot}        //*[@id="robot-preview-image"]

    # This is supposed to help with network congestion (I hope)
    # when loading an image takes too long and we will only end up with a partial download.
    Wait Until Element Is Visible   ${img_robot}
    Wait Until Element Is Visible   ${lbl_orderid} 

    #get the order ID   
    ${orderid}=                     Get Text            //*[@id="receipt"]/p[1]

    # Create the File Name
    Set Local Variable              ${fully_qualified_img_filename}    ${img_folder}${/}${orderid}.png

    # The sleep command is a dirty workaround for the case where one part of the three-folded image has not yet been loaded
    # This can happen at very throttled download speeds and results in an incomplete target image.
    # A preference would be to have a keyword such as "Wait until image has been downloaded" over this quick hack
    # but even Selenium does not support this natively. 
    #
    # Sorry mates - I mainly use Robot Framework for REST APIs. Web testing is not my primary domain :-)
    #
    Sleep   1sec
    Log To Console                  Capturing Screenshot to ${fully_qualified_img_filename}
    Capture Element Screenshot      ${img_robot}    ${fully_qualified_img_filename}
    
    [Return]    ${orderid}  ${fully_qualified_img_filename}

Store the receipt as a PDF file
...  [Arguments]        ${ORDER_NUMBER}

     Wait Until Element Is Visible   //*[@id="receipt"]
     Log To Console                  Printing ${ORDER_NUMBER}
     ${order_receipt_html}=          Get Element Attribute   //*[@id="receipt"]  outerHTML

     Set Local Variable              ${fully_qualified_pdf_filename}    ${pdf_folder}${/}${ORDER_NUMBER}.pdf

     Html To Pdf                     content=${order_receipt_html}   output_path=${fully_qualified_pdf_filename}

     [Return]    ${fully_qualified_pdf_filename}

Go to order another robot
    # Define local variables for the UI elements
    Set Local Variable      ${btn_order_another_robot}      //*[@id="order-another"]
    Click Button            ${btn_order_another_robot}

Log Out And Close The Browser
    Close Browser

Create a Zip File of the Receipts
    Archive Folder With ZIP     ${pdf_folder}  ${zip_file}   recursive=True  include=*.pdf

Embed the robot screenshot to the receipt PDF file
    [Arguments]     ${IMG_FILE}     ${PDF_FILE}

    Log To Console                  Printing Embedding image ${IMG_FILE} in pdf file ${PDF_FILE}

    Open PDF        ${PDF_FILE}

    # Create the list of files that is to be added to the PDF (here, it is just one file)
    @{myfiles}=       Create List     ${IMG_FILE}:x=0,y=0

    
    Add Files To PDF    ${myfiles}    ${PDF_FILE}     ${True}    