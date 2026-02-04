{
  "indexes": [
    {
      "collectionGroup": "notifications",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "userId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "createdAt",
          "order": "DESCENDING"
        }
      ]
    },
    {
      "collectionGroup": "notifications",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "userId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "isRead",
          "order": "ASCENDING"
        }
      ]
    },
    {
      "collectionGroup": "assignments",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "teacherId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "createdAt",
          "order": "DESCENDING"
        }
      ]
    },
    {
      "collectionGroup": "assignments",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "classIds",
          "arrayConfig": "CONTAINS"
        },
        {
          "fieldPath": "deadline",
          "order": "ASCENDING"
        }
      ]
    },
    {
      "collectionGroup": "submissions",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "assignmentId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "submittedAt",
          "order": "DESCENDING"
        }
      ]
    },
    {
      "collectionGroup": "submissions",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "assignmentId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "studentId",
          "order": "ASCENDING"
        }
      ]
    },
    {
      "collectionGroup": "classes",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "teacherId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "createdAt",
          "order": "DESCENDING"
        }
      ]
    },
    {
      "collectionGroup": "users",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "studentCode",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "accountType",
          "order": "ASCENDING"
        }
      ]
    }
  ],
  "fieldOverrides": []
}