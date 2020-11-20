public inherited sharing class RecordCreationHelper {
    
    @AuraEnabled
    public static String createRecord(String objectName, String contentDocumentId){
        List<SObject> lstToCreate;

        // Query the Document
        ContentDocument cd = [SELECT Id, LatestPublishedVersionId FROM ContentDocument WHERE Id=:contentDocumentId WITH SECURITY_ENFORCED];
        ContentVersion cv = [SELECT Id, VersionData FROM ContentVersion WHERE Id=:cd.LatestPublishedVersionId WITH SECURITY_ENFORCED];
        
        // Query the object mapping config
        List<Customer_Fields__mdt> lstcmdts = [
            SELECT
            First_Name__r.QualifiedAPIName,
            Last_Name__r.QualifiedAPIName,
            Phone__r.QualifiedAPIName,
            Email__r.QualifiedAPIName,
            Org__r.QualifiedAPIName
            FROM Customer_Fields__mdt
            WHERE Object_Name__r.QualifiedAPIName = :objectName
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        Customer_Fields__mdt cmdt = lstcmdts[0];
        
        
        // Call Einstein OCR    
        Map<String, String> businessCardInfo = new Map<String, String> ();
        einsteinplay.Einstein_PredictionService einsteinService = new einsteinplay.Einstein_PredictionService(
            einsteinplay.Einstein_PredictionService.Types.OCR
        );
        einsteinplay.Einstein_PredictionResult response = einsteinService.predictOcrBase64('OCRModel',EncodingUtil.base64encode(cv.VersionData),'CONTACT', 'DTXDEMO');
        for (einsteinplay.Einstein_Probability probability: response.probabilities) {
            businessCardInfo.put(probability.attributes.tag, probability.label);
        }
        
        // Creating a new sObject based on results from Einstein
        Schema.SObjectType targetType = Schema.describeSObjects(new String[]{objectName})[0]?.getSObjectType();
                                                                   


        SObject recordToInsert = targetType.newSObject();
        if(cmdt != null){
            System.debug(cmdt);
            System.debug(businessCardInfo);
            String personName = businessCardInfo.get('PERSON');
            String firstName = personName?.split(' ')[0];
            String lastName = personName?.split(' ')[1];
            String phone = businessCardInfo.get('PHONE');
            String email = businessCardInfo.get('EMAIL');
            String org = businessCardInfo.get('ORG');
            recordToInsert.put(cmdt.First_Name__r.QualifiedAPIName, firstName?.trim());
            recordToInsert.put(cmdt.Last_Name__r.QualifiedAPIName, lastName?.trim());
            recordToInsert.put(cmdt.Phone__r.QualifiedAPIName,phone);
            recordToInsert.put(cmdt.Email__r.QualifiedAPIName,email);
            recordToInsert.put(cmdt.Org__r.QualifiedAPIName,org);
            
            // Check for CRUD and FLS
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.CREATABLE,
                new List<SObject>{ recordToInsert },
                true
            );
            lstToCreate = decision.getRecords();
            try {
                insert lstToCreate;
                
                // Send Custom Notifications
                CustomNotificationType cnt = [SELECT Id, CustomNotifTypeName, DeveloperName from CustomNotificationType WHERE DeveloperName = 'NEW_CONTACT' WITH SECURITY_ENFORCED];
                Messaging.CustomNotification obj = new Messaging.CustomNotification();
                obj.setNotificationTypeId(cnt.Id);
                obj.setTargetId(lstToCreate[0].Id);
                obj.setTitle('A new record ' + firstName + ' ' + lastName +' has been created');
                obj.setBody('A new record by scanning a business card has been created');
                obj.send(new Set<String>{UserInfo.getUserId()});
                
                return lstToCreate[0].Id;
            } catch (exception e) {
                throw new AuraHandledException(e.getMessage());
            }
        }
        
        return lstToCreate[0].Id;
        
    }
    
}