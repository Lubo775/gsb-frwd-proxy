import boto3 # type: ignore
import os

from cryptography import x509 # type: ignore
from cryptography.hazmat.backends import default_backend # type: ignore
from datetime import datetime

s3 = boto3.client('s3')
sns = boto3.client('sns')

##############################################################
#ENV VARS
stage = os.environ['stage']
daysLeft = int(os.environ['daysLeftToExpire'])
bucketName = os.environ['bucketName']
##############################################################
  
# Fn to parse email body based on condition whether one or more certificates are about to expire  
def emailBodyCreator(numberOfCerts, serviceName, daysUntilExpirationArr, certSubjectArr, certIssuerArr, validFromThisDateArr, validTillThisDateArr):
    
    body1Singular='''Dear subscriber,\n\nCertificate for service {serviceName} is going to expire!\n\n'''.format(serviceName=serviceName)
    body1Plural='''Dear subscriber,\n\nCertificates for service {serviceName} are going to expire! Here is list of those:\n\n'''.format(serviceName=serviceName)
    body2Singular='''Certificate Subject: {certSubject}\nCertificate Issuer: {certIssuer}\nCertificate valid from: {validFromThisDate}\nCertificate not valid after: {validTillThisDate}\nExpiration in {daysUntilExpiration} days\n\n'''.format(certSubject=certSubjectArr[0],certIssuer=certIssuerArr[0],validFromThisDate=validFromThisDateArr[0],validTillThisDate=validTillThisDateArr[0], daysUntilExpiration=daysUntilExpirationArr[0])
    body3='''Please update your certificates and do not forget to delete expired public key and upload new public key into s3 bucket for further notifications in the future.'''
    finalizedBody2=''''''
    
    if numberOfCerts == 1:
        return body1Singular+body2Singular+body3
    else:
        for x in range(numberOfCerts):
            body2Plural='''Certificate Subject: {certSubject}\nCertificate Issuer: {certIssuer}\nCertificate valid from: {validFromThisDate}\nCertificate not valid after: {validTillThisDate}\nExpiration in {daysUntilExpiration} days\n\n'''.format(certSubject=certSubjectArr[x],certIssuer=certIssuerArr[x],validFromThisDate=validFromThisDateArr[x],validTillThisDate=validTillThisDateArr[x], daysUntilExpiration=daysUntilExpirationArr[x])
            finalizedBody2=finalizedBody2 + body2Plural
        
        return body1Plural+finalizedBody2+body3
   
# Get SNS topic ARN for specific service
def getSNSTopic(serviceName, isGSBProxy):
    
    # Look for ARN of topic to which message will be sent (calling create_topic API is only way how to retrieve ARN at this time). If topic does not exist, create new topic for that specific service.
    if isGSBProxy == True:
        topicName='gsbproxy-cert-expiration'
    else:
        topicName=serviceName+'-cert-expiration'
        
    topic = sns.create_topic(Name=topicName, Tags=[{'Key': 'Owners', 'Value': 'GSBProxy'}])
    topic_arn = topic.get('TopicArn')
    
    return topic_arn
    
def successLambdaResponse():
    print ('Lambda invocation was successful. All messages were sent to SNS topics in case certificates are about to expire')
    
def lambda_handler(event, context):
    
    # Define arrays
    daysUntilExpirationArr = []
    certSubjectArr = []
    certIssuerArr = []
    validFromThisDateArr = []
    validTillThisDateArr = []
    servicesArr = []
    
    breakLoop = False
    
    # Retrieve service folder name
    s3_response = s3.list_objects_v2(
        Bucket= bucketName,
        #Prefix='CertNotification'
        Delimiter='/'
    )
    # Count number of folders in s3 (service names)
    numberOfServices=len(s3_response['CommonPrefixes'])
    
    # Store service names into serviceArr array
    for o in range (numberOfServices):
        servicesArr.append(s3_response['CommonPrefixes'][o]['Prefix'])
    
    # Get number of services
    servicesArrLength=len(servicesArr)
    
    # Loop through each service folder in s3
    for b in range(servicesArrLength):
        
        # Retrieve folder in bucket where certificates for specific service reside
        s3_response = s3.list_objects_v2(
            Bucket= bucketName,
            Prefix=servicesArr[b]
        )
        
        # Clean service name (remove slash character)
        serviceName=servicesArr[b].replace('/', '')
        
        print('Checking certificates for service: ', serviceName)
        
        # Count number of certs to be processed for specific service
        numberOfCerts=len(s3_response['Contents']) - 1
        if numberOfCerts <= 0:
            continue
       
        # Clear arrays before working with them
        daysUntilExpirationArr.clear()
        certSubjectArr.clear()
        certIssuerArr.clear()
        validFromThisDateArr.clear()
        validTillThisDateArr.clear()
        
        # Loop through all certs for specific service
        for i in range(1, numberOfCerts + 1):
            certName=s3_response['Contents'][i]['Key']
            print('Checking validity of this certificate: ', certName)
            
            # Retrieve content of specific certificate from s3
            retrievedCert=s3.get_object(
                Bucket=bucketName,
                Key=certName
            )
            # Decode retrieved certificate
            retrievedCertBody = retrievedCert.get('Body')
            decodedCert = retrievedCertBody.read().decode()
            
            # Parse the X.509 certificate
            try:
                certificate = x509.load_pem_x509_certificate(decodedCert.encode(), default_backend())
            # In a case of error send email directly to GSBProxy (as owners of Lambda) to notify something went wrong.
            except Exception as e:
                print('Error with certificate:', certName, 'Certificates wont be properly checked for service:', serviceName)
                
                # Publish message to GSB Proxy SNS topic to inform them about issue with Lambda and jump out of for loop for service with error
                isGSBProxy = True
                topic_arn = getSNSTopic(serviceName, isGSBProxy)
                body = 'Issue happened while reading PEM certificate specifically for this certificate: ' + certName + '\nHere is the error:\n' + str(e)
                sns.publish(TopicArn=topic_arn,Subject='Cert notification Lambda Error',Message=str(body))
                
                breakLoop = True
                break
            
            # Access the certificate's information
            certSubject = str(certificate.subject)[6:-2]
            certIssuer = str(certificate.issuer)[6:-2]
            validFromThisDate = certificate.not_valid_before
            validTillThisDate = certificate.not_valid_after
            
            # Actual date in real life
            realDate = datetime.now()
            
            # Find out number of days till expiration
            if (validTillThisDate - realDate).days < daysLeft :
                
                # Calculate the number of days until the certificate expires and add it to array
                daysUntilExpirationArr.append((validTillThisDate - realDate).days)
                
                # Add cert subject into array
                certSubjectArr.append(certSubject)
                
                # Add cert issuer into array
                certIssuerArr.append(certIssuer)
                
                # Add cert issuance day into array
                validFromThisDateArr.append(validFromThisDate)
                
                # Add cert expiration day into array
                validTillThisDateArr.append(validTillThisDate)
            else :
                # Lower number of certs to have only those which are going to expire in near future
                numberOfCerts = numberOfCerts - 1
        
        # Due to error from try/except block above skip one for loop
        if breakLoop == True:
            breakLoop = False
            continue
        
        isGSBProxy = False
        topic_arn = getSNSTopic(serviceName, isGSBProxy)
        
        if numberOfCerts >= 1:
            # Pick subject string based on number of certificates about to expire for specific service
            if numberOfCerts == 1:
                subject="Certificate is about to expire in {stage} stage !".format(stage=stage)  
            else:
                subject="Certificates are about to expire in {stage} stage !".format(stage=stage)
        
            # Call function to puzzle out correct format of email body message.
            body=emailBodyCreator(numberOfCerts, serviceName, daysUntilExpirationArr, certSubjectArr, certIssuerArr, validFromThisDateArr, validTillThisDateArr)
        
            # Publish message to correct SNS Topic
            sns_response = sns.publish(TopicArn=topic_arn,Subject=subject,Message=str(body))
        
            # Provide error in case Lambda was unable to publish message to topic
            if sns_response['ResponseMetadata'].get('HTTPStatusCode') != 200:
                return (print('For some reason Lambda is unable to publish message into SNS topic. Return code from sns.publish() was not 200'))
    
    # General success response message for Cloud Watch         
    return successLambdaResponse()
