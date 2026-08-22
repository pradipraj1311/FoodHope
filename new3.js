rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    function isSignedIn() { return request.auth != null; }
    
    function isAdmin() {
      return isSignedIn() && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
    }

    match /users/{userId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn();
      allow update: if isSignedIn() && (request.auth.uid == userId || isAdmin());
      // એકાઉન્ટ ડિલીટ કરવાની પરમિશન
      allow delete: if isSignedIn() && request.auth.uid == userId;
    }

    match /donations/{donationId} {
      allow read, create, update: if isSignedIn();
      allow delete: if isAdmin() || (isSignedIn() && resource.data.donorUid == request.auth.uid);
    }

    match /squads/{squadId} {
      allow read, write: if isSignedIn();
      
      // Activities સબ-કલેક્શન માટે પરમિશન (આ ભૂલ સુધારશે)
      match /activities/{activityId} {
        allow read, write: if isSignedIn();
      }
    }
  }
}