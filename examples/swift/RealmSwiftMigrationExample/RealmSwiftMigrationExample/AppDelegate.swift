////////////////////////////////////////////////////////////////////////////
//
// Copyright 2014 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

import UIKit
import Realm

// Old data models
/* V0
class Person: RLMObject {
    dynamic var firstName = ""
    dynamic var lastName = ""
    dynamic var age = 0
}
*/

/* V1
class Person: RLMObject {
    dynamic var fullName = ""        // combine firstName and lastName into single field
    dynamic var age = 0
}
*/

/* V2 */
class Pet: RLMObject {
    dynamic var name = ""
    dynamic var type = ""
}

class Person: RLMObject {
    dynamic var fullName = ""
    dynamic var age = 0
    dynamic var pets = RLMArray(objectClassName: Pet.className())
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
                            
    var window: UIWindow?

    func application(application: UIApplication!, didFinishLaunchingWithOptions launchOptions: NSDictionary!) -> Bool {
        self.window = UIWindow(frame: UIScreen.mainScreen().bounds)
        // Override point for customization after application launch.
        self.window!.backgroundColor = UIColor.whiteColor()
        self.window!.makeKeyAndVisible()
        let rootVC = UIViewController()
        self.window!.rootViewController = rootVC

        // define a migration block
        // you can define this inline, but we will reuse this to migrate realm files from multiple versions
        // to the most current version of our data model
        let migrationBlock: RLMMigrationBlock = { migration, oldSchemaVersion in
            if oldSchemaVersion < 1 {
                migration.enumerateObjects(Person.className()) { oldObject, newObject in
                    if oldSchemaVersion < 1 {
                        // combine name fields into a single field
                        let firstName = oldObject["firstName"] as String
                        let lastName = oldObject["lastName"] as String
                        newObject["fullName"] = "\(firstName) \(lastName)"
                    }
                }
            }
            if oldSchemaVersion < 2 {
                migration.enumerateObjects(Person.className()) { oldObject, newObject in
                    // give JP a dog
                    if newObject["fullName"] as String == "JP McDonald" {
                        let jpsDog = Pet(object: ["Jimbo", "dog"])
                        newObject["pets"].addObject(jpsDog)
                    }
                }
            }

            // return the new schema version
            return 2
        }

        //
        // Migrate the default realm over multiple data model versions
        //
        let docsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as String
        let defaultPath = docsPath.stringByAppendingPathComponent("default.realm")

        // copy over old data file for v0 data model
        let v0Path = NSBundle.mainBundle().resourcePath.stringByAppendingPathComponent("default-v0.realm")
        NSFileManager.defaultManager().removeItemAtPath(defaultPath, error: nil)
        NSFileManager.defaultManager().copyItemAtPath(v0Path, toPath: defaultPath, error: nil)

        // migrate default realm at v0 data model to the current version
        RLMRealm.migrateDefaultRealmWithBlock(migrationBlock)

        // print out all migrated objects in the default realm
        println("Migrated objects in the default Realm: \(Person.allObjects())")

        //
        // Migrate a realms at a custom paths
        //
        let v1Path = NSBundle.mainBundle().resourcePath.stringByAppendingPathComponent("default-v1.realm")
        let v2Path = NSBundle.mainBundle().resourcePath.stringByAppendingPathComponent("default-v2.realm")
        let realmv1Path = docsPath.stringByAppendingPathComponent("default-v1.realm")
        let realmv2Path = docsPath.stringByAppendingPathComponent("default-v2.realm")

        NSFileManager.defaultManager().removeItemAtPath(realmv1Path, error: nil)
        NSFileManager.defaultManager().copyItemAtPath(v1Path, toPath: realmv1Path, error: nil)
        NSFileManager.defaultManager().removeItemAtPath(realmv2Path, error: nil)
        NSFileManager.defaultManager().copyItemAtPath(v2Path, toPath: realmv2Path, error: nil)

        // migrate realms at custom paths
        RLMRealm.migrateRealmAtPath(realmv1Path, withBlock: migrationBlock)
        RLMRealm.migrateRealmAtPath(realmv2Path, withBlock: migrationBlock)

        // print out all migrated objects in the migrated realms
        let realmv1 = RLMRealm.realmWithPath(realmv1Path, readOnly: false, error: nil)
        println("Migrated objects in the Realm migrated from v1: \(Person.allObjectsInRealm(realmv1))")
        let realmv2 = RLMRealm.realmWithPath(realmv2Path, readOnly: false, error: nil)
        println("Migrated objects in the Realm migrated from v2: \(Person.allObjectsInRealm(realmv2))")

        return true
    }
}
