"
I am responsible for generating kebab-cased Exercism edirectories, each containing a seperate exercise for users.

We have to do it this way as Exercism conventions differ from Tonel, and so we need to output them to a seperate directory suitable for  the Exercism command line tool.

When you have created a new exercise(s) that you are happy with, you need to run a generation.

You can either click on the #generate example method and be prompted for a file location or evaluate the following  (where the path is one that points to where you have checked out the entire pharo project using either the command line or a git tool):

ExercismGenerator generateTo: (FileLocator home / 'Dev/Exercism/pharo-git') pathString
"
Class {
	#name : #ExercismGenerator,
	#superclass : #Object,
	#classVars : [
		'DefaultPath'
	],
	#category : #'ExercismDev-Generator'
}

{ #category : #helper }
ExercismGenerator class >> defaultPath [
	^ DefaultPath ifNil: [ self defaultPath: FileLocator home pathString]
]

{ #category : #helper }
ExercismGenerator class >> defaultPath: pathString [
	^ DefaultPath := pathString
]

{ #category : #generation }
ExercismGenerator class >> generate [
	"This is the entry point for generating exercism compatible source files that can be checked into
	the exercism/pharo project. e.g. self generate"

	<example>
	| path |
	path := UIManager default
		chooseDirectory: 'Select the /exercises location in a full Exercism/Pharo git project'
		path: self defaultPath.
		
	path ifNotNil: [ self new generateTo: (self defaultPath: path) ]
]

{ #category : #generation }
ExercismGenerator class >> packagesExercismMenuGenerate: aBuilder [
	<nautilusGlobalPackageMenu>
	| target packageTree |
	
	target := aBuilder model.
	(packageTree := target selectedPackage) ifNil: [ ^ target ].
	(packageTree packageName = 'Exercism') ifFalse: [ ^ target ].
	
	(aBuilder item: #'Generate Exercises...')
		parent: #'Exercism';
		action: [ ExercismGenerator generate ];
		order: 50;
		withSeparatorAfter;
		help: 'Generate the Exercism templates into an existing git repository'.
	
]

{ #category : #helper }
ExercismGenerator >> createTagSnapshotFor: packageOrTag [
	| parentSnapshot |
	
	parentSnapshot := (MCPackage named: packageOrTag package name) snapshot.
	
	^ MCSnapshot
		fromDefinitions:
			(parentSnapshot definitions
				select:
					[ :mc | mc className isNil or: [ mc actualClass category endsWith: packageOrTag name ] ])
]

{ #category : #helper }
ExercismGenerator >> generateReadmeHintFor: packageOrTag to: destinationDirectory [
	"Generate markdown hints, that exercism configlet will pickup for readme.md files
	see: https://github.com/exercism/docs/blob/master/language-tracks/exercises/anatomy/readmes.md#generating-a-readme"
	
	packageOrTag classes
		detect: [ :c | c isTestCase ]
		ifFound: [ :c | (destinationDirectory / 'hints.md') writeStream nextPutAll: c comment ]
]

{ #category : #helper }
ExercismGenerator >> generateSourceFilesFor: packageOrTag to: filePathString [
	"Generate the Tonel source files for a package (normally a tag). Answer the exercise directory reference"

	| writer exampleDirectoryRef exerciseDirectoryRef metaDirectoryRef  solutionDirectoryRef testClass testClassFilename exerciseName |
	
	"Note: could create the writer on a memory stream to then pick what should be stored on disk
	e.g.
		mem := FileSystem memory root.
		writer := ExTonelWriter on: mem."

	exerciseName := packageOrTag name asKebabCase.
	exampleDirectoryRef := filePathString asFileReference.
	exerciseDirectoryRef := exampleDirectoryRef / exerciseName.
	metaDirectoryRef :=  exerciseDirectoryRef / '.meta'.
	solutionDirectoryRef := metaDirectoryRef / 'solution'.
	
	exerciseDirectoryRef ensureCreateDirectory.
	exerciseDirectoryRef deleteAll.
	
	(writer := ExTonelWriter new)
		packageDir: (solutionDirectoryRef relativeTo: exampleDirectoryRef) pathString;
		sourceDir: exampleDirectoryRef;
		writeSnapshot: (self createTagSnapshotFor: packageOrTag).

	"Remove the extra package file as its not needed for Exercism"
	(solutionDirectoryRef / 'package.st') delete.
	
	self generateReadmeHintFor: packageOrTag to: metaDirectoryRef.
	
	"Move the test file down to the exerciseDirectory"
	testClass := packageOrTag classes detect: [ :cls | cls isTestCase  ].
	testClassFilename := testClass name, '.class.st'.
	(solutionDirectoryRef / testClassFilename) moveTo: exerciseDirectoryRef / testClassFilename.
	
	^exerciseDirectoryRef 

]

{ #category : #generation }
ExercismGenerator >> generateTo: filePathReference [
	| cmd result |
	
	(RPackage organizer packageNamed: 'Exercism') packages do: [:pkg |
			self generateSourceFilesFor: pkg to: filePathReference ].
		
	cmd := 'configlet generate ', (filePathReference resolveString: '..') pathString.		
	result := PipeableOSProcess waitForCommand: cmd.
	
	result succeeded
		ifFalse: [ 
			self error: 'failure running "configlet generate" - ' , result outputAndError printString ]
]
