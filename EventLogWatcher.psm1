Function Export-SerializedStream
{
<#

.SYNOPSIS
    Exports serializable objects to a file, using a BinaryFormatter.

.DESCRIPTION
    The Export-SerializedStream function exports serializable objects to a file, using a BinaryFormatter. These files 
    can then be deserialized back into usable objects using Import-SerializedStream.

    Using Export-CliXML will return a "Deserialized" object, while this method will return an object of the same type.

.PARAMETER InputObject
    Object to be serialized into a file.  Object type must be serializable.
    
.PARAMETER StreamPath
    Full path and filename for the serialized object output file.

.EXAMPLE

    C:\PS> $EventRecord = Get-WinEvent -MaxEvents 1
    C:\PS> $EventBookmark = $EventRecord.Bookmark

    C:\PS> Export-SerializedStream $EventBookmark ".\bookmark.stream"


    Description
    -----------
    This example serializes and exports an EventBookmark object to a file, which can be later deserialized back into
    the same object type using Import-SerializedStream.

#>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True)]
        [psobject[]]$InputObject,
        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True)]
        [string[]]$StreamPath
    )
    PROCESS
    {
        If ($InputObject.count -eq $StreamPath.count)
        {
            for($i=0; $i -lt $InputObject.Count; ++$i)
            {
                If ($StreamPath[$i].StartsWith(".\"))
                {
                   $StreamPath[$i] = (Convert-Path (Get-Location -PSProvider FileSystem)) + "\" + $StreamPath[$i].TrimStart(".\")
                }
                If ([System.IO.Path]::IsPathRooted($StreamPath[$i]))
                {
                    If ($InputObject[$i].GetType().IsSerializable)
                    {
                        Try
                        {
                            If (Test-Path $StreamPath[$i])
                            {
                                $FileStream = New-Object System.IO.FileStream $StreamPath[$i],([io.filemode]::Truncate),([io.fileaccess]::readwrite),([io.fileshare]::none)
                            } else {
                                $FileStream = New-Object System.IO.FileStream $StreamPath[$i],([io.filemode]::OpenOrCreate),([io.fileaccess]::readwrite),([io.fileshare]::none)
                            }
                            
                            $formatter = New-Object System.Runtime.Serialization.Formatters.Binary.BinaryFormatter
                            $formatter.Serialize($FileStream, $InputObject[$i])
                            $FileStream.Close()
                            $FileStream.Dispose()
                        }
                        catch [System.Exception]
                        {
                            Write-Error ("Could not serialize stream: {0} for type: {1}`nERROR: {2}" -f $StreamPath[$i],$InputObject[$i].GetType(),$_.Exception.Message)
                            If ($FileStream)
                            {
                                $FileStream.Close()
                                $FileStream.Dispose()
                            }
                        }
                    } else {
                        Write-Error ("Object of type: {0} is not serializable" -f $InputObject[$i].GetType())
                    }
                } else {
                    write-Error ("Invalid path: {0}`nERROR: Full path required (Example 'C:\test.stream')" -f $StreamPath[$i])
                }
            } 
        } else {
            Write-Error ("Number of InputObjects: {0} does not equal number of StreamPaths: {1}" -f $InputObject.Count,$StreamPath.Count) 
        }
    }
} 


Function Import-SerializedStream
{
<#

.SYNOPSIS
    Imports serialized objects exported with Export-SerializedStream from a file using a BinaryFormatter.

.DESCRIPTION
    Imports serialized objects exported with Export-SerializedStream from a file using a BinaryFormatter.
    The same object type is returned after the file is deserialized.

.PARAMETER StreamPath
    Full path and filename for the serialized object input file.

.EXAMPLE
    C:\PS> $EventBookmark = Import-SerializedStream ".\bookmark.stream"
    
    
    Description
    -----------
    This example deserializes and imports an EventBookmark object from a file previously serialized with Export-SerializedStream

.EXAMPLE
    C:\PS> $EventBookmark = ".\bookmark.stream" | Import-SerializedStream
    
    
    Description
    -----------
    This example is the same result as Example 1, but uses the pipeline to input the StreamPath parameter.

#>
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
        [string[]]$StreamPath
    )
    PROCESS
    {
        Foreach ($path in $StreamPath)
        {
            If ($Path.StartsWith(".\"))
            {
                $Path = (Convert-Path (Get-Location -PSProvider FileSystem)) + "\" + $Path.TrimStart(".\")
            }
            If ([System.IO.Path]::IsPathRooted($Path))
            {
                Try
                {
                    If (Test-Path $Path)
                    {
                        $FileStream = New-Object System.IO.FileStream $Path,([io.filemode]::open),([io.fileaccess]::readwrite),([io.fileshare]::none)
                        $Formatter = New-Object System.Runtime.Serialization.Formatters.Binary.BinaryFormatter
                        $obj = $Formatter.Deserialize($FileStream)
                        $FileStream.Close()
                        $FileStream.Dispose()
                    
                        Write-Output $obj
                    } else {
                        Write-Error ("Could not load bookmark: {0} `nERROR: File not found." -f $Path)
                    }
                }
                Catch [System.Exception]
                {
                    Write-Error ("Could not deserialize stream: {0} `nERROR: {1}" -f $Path,$_.Exception.Message)
                    If ($FileStream)
                    {
                        $FileStream.Close()
                        $FileStream.Dispose()
                    }
                }
            } else {
                write-Error ("Invalid path: {0}`nERROR: Full path required (Example 'C:\test.stream')" -f $StreamPath[$i])
            }
        }
    }
}


Function Get-BookmarkToStartFrom 
{
<#

.SYNOPSIS
    Gets a previously serialized EventBookmark object at the location specified.

.DESCRIPTION
    The Get-BookmarkToStartFrom function gets a previously serialized EventBookmark 
    [System.Diagnostics.Eventing.Reader.EventBookmark] object from the location specified.
    
    The returned EventBookmark can be used as a placeholder to resume an EventLogWatcher from where it left off.

.PARAMETER BookmarkStreamPath
    Full path and filename for the serialized object input file. 
    
    DEFAULT = '.\bookmark.stream'
    
    
.EXAMPLE
    C:\PS> $EventBookmark = Get-BookmarkToStartFrom
    
    
    Description
    -----------
    This example returns a previously serialized EventBookmark object from the default location ".\bookmark.stream"
    
    
.EXAMPLE
    C:\PS> $EventBookmark = Get-BookmarkToStartFrom "C:\EventLogWatchers\Application\App_bookmark.stream"
    
    
    Description
    -----------
    This example returns a previously serialized EventBookmark object from 
    "C:\EventLogWatchers\Application\App_bookmark.stream"
    
#>
    [CmdletBinding()]
    Param
    (
        [Parameter(ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
        [string[]]$BookmarkStreamPath = ".\bookmark.stream"
    )
    PROCESS
    {
        Foreach ($Path in $BookmarkStreamPath)
        {
            If (Test-Path $Path)
            {
                If ($Path.StartsWith(".\"))
                {
                    $Path = (Convert-Path (Get-Location -PSProvider FileSystem)) + "\" + $Path.TrimStart(".\")
                }
                
                Try
                {
                    $BookmarkToStartFrom = Import-SerializedStream $Path
                    Write-Output $BookmarkToStartFrom
                }
                Catch [System.Exception]
                {
                    Write-Error ("Exception determining BookmarkToStartFrom: {0} `nERROR: {1}" -f $Path,$_.Exception.Message)
                }
            } else {
                write-verbose ("File not found in path: {0} Returning Null value" -f $Path)
                write-output $Null
            }
        }
    }
}

Function New-EventLogQuery
{
<#

.SYNOPSIS
    Creates a new EventLogQuery object based on the information specified.

.DESCRIPTION
    The New-EventLogQuery function creates a new EventLogQuery object 
    [System.Diagnostics.Eventing.Reader.EventLogQuery] based on the information specified by the input parameters.  
    The resulting object can be used for creating an EventLogWatcher.

.PARAMETER LogName
    The name of the event log to query, or the path to the event log file to query.

.PARAMETER Query
    The event query used to retrieve events that match the query conditions.
    
    DEFAULT = "*"

.PARAMETER PathType
    Specifies whether the string used in the path parameter specifies the name of an event log, or the path to an 
    event log file.
    
    DEFAULT = [System.Diagnostics.Eventing.Reader.PathType]::LogName
    

.EXAMPLE
    C:\PS> $EventLogQuery = New-EventLogQuery "Application"
    
    
    Description
    -----------
    This example creates a EventLogQuery object for all events in the Application Log.
    
    
.EXAMPLE
    C:\PS> $EventLogQuery = New-EventLogQuery "Security" -query "*[System[(EventID=4740)]]"
    
    
    Description
    -----------
    This example uses an XPATH query to create an EventLogQuery object for all events with Event ID 4740 from the 
    Security Log.


.EXAMPLE
    C:\PS> $EventLogQuery = New-EventLogQuery "ForwardedEvents"
    
    
    Description
    -----------
    This example creates a EventLogQuery object for all events in the subscribed to in the ForwardedEvents Log.
    
    
#>
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True)]
        [string]$LogName,
        
        [Parameter(ValueFromPipelinebyPropertyName=$True)]
        [string]$Query = "*",
        
        [Parameter(ValueFromPipelinebyPropertyName=$True)]
        [System.Diagnostics.Eventing.Reader.PathType]$PathType = [System.Diagnostics.Eventing.Reader.PathType]::LogName    
    )
    PROCESS
    {
        Try
        {
            $EventLogQuery = New-Object System.Diagnostics.Eventing.Reader.EventLogQuery $LogName,$PathType,$query
            Write-Output $EventLogQuery
        }
        Catch [System.Exception]
        {
            Write-Error ("Error creating new EventLogQuery for LogName: {0} PathType: {1} Query: {2}`nERROR: {3}" -f $LogName,$PathType,$Query,$_.Exception.Message)
        }
    }
}

Function New-EventLogWatcher
{
<#

.SYNOPSIS
    Creates a new EventLogWatcher object based on the information specified.

.DESCRIPTION
    The New-EventLogWatcher function creates a new EventLogWatcher object 
    [System.Diagnostics.Eventing.Reader.EventLogWatcher] based on the information specified by the input parameters.  
    The resulting object EventRecordWritten Event can be registered to perform a given action when triggered.
    
    IMPORTANT: The EventLogWatcher must be enabled for any events to be triggered, but this SHOULD NOT be done until 
    the Event is registered.  If the EventLogWatcher is enabled prior to the EventRecordWritten Event being 
    registered, then the EventLogWatcher will process through Windows Event Log events without being captured.
    
    To ENABLE the returned EventLogWatcher:
        $EventLogWatcher.Enabled = $True
    
    To DISABLE the returned EventLogWatcher:
        $EventLogWatcher.Enabled = $False   

.PARAMETER EventLogQuery
    Specifies a query for the event subscription. When an event is logged that matches the criteria expressed 
    in the query, then the EventRecordWritten Event is raised.  
    
    An EventLogQuery can be created using New-EventLogQuery.

.PARAMETER BookmarkToStartFrom
    The bookmark (placeholder) used as a starting position in the event log or stream of events. Only events 
    that have been logged after the bookmark event will be returned by the query.

    An EventBookmark can be retrieved using Get-BookmarkToStartFrom.
    
    DEFAULT = $Null

.EXAMPLE
    C:\PS> $EventLogWatcher = New-EventLogWatcher $EventLogQuery 
    
    
    Description
    -----------
    This example creates an EventLogWatcher object based on the information provided in the EventLogQuery object.  
    Since there is no EventBookmark provided, the EventLogWatcher will start at the first event when enabled.
 
    
.EXAMPLE
    C:\PS> $EventLogWatcher = New-EventLogWatcher $EventLogQuery $BookmarkToStartFrom
    
    
    Description
    -----------
    This example creates an EventLogWatcher object based on the information provided in the EventLogQuery object.  
    The EventLogWatcher will begin from the EventBookmark placeholder provided in BookmarkToStartFrom.
             
#>
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True)]
        [System.Diagnostics.Eventing.Reader.EventLogQuery]$EventLogQuery,
        
        [Parameter(ValueFromPipelinebyPropertyName=$True)]
        [System.Diagnostics.Eventing.Reader.EventBookmark]$BookmarkToStartFrom = $Null
    )
    PROCESS
    {
        Try
        {
            If ($BookmarkToStartFrom -eq $Null)
            {
                $EventLogWatcher = New-Object System.Diagnostics.Eventing.Reader.EventLogWatcher $EventLogQuery, $Null, $true
            } else {
                $EventLogWatcher = New-Object System.Diagnostics.Eventing.Reader.EventLogWatcher $EventLogQuery, $BookmarkToStartFrom
            }
            Write-Output $EventLogWatcher
        }
        Catch [System.Exception]
        {
            Write-Error ("Error creating new EventLogWatcher`nERROR: {0}" -f $_.Exception.Message)
        }
    }
}

Function Register-EventRecordWrittenEvent
{
<#

.SYNOPSIS
    Registers the EventRecordWritten event of the EventLogWatcher object specified.

.DESCRIPTION
    The Register-EventRecordWrittenEvent registers the EventRecordWritten event of the EventLogWatcher object 
    specified. A ScriptBlock can be associated to trigger each time this event is raised, by passing the code 
    to the Action parameter.

    IMPORTANT: The associated EventLogWatcher must be enabled for any events to be triggered, but this 
    SHOULD NOT be done until the Event is registered.  If the EventLogWatcher is enabled prior to the 
    EventRecordWritten Event being registered, then the EventLogWatcher will process through Windows Event Log 
    events without being captured.
    
    To ENABLE the returned EventLogWatcher:
        $EventLogWatcher.Enabled = $True
    
    To DISABLE the returned EventLogWatcher:
        $EventLogWatcher.Enabled = $False 


.PARAMETER InputObject
    The EventLogWatcher object which will raise the associated EventRecordWritten Event that will be subscribed 
    to using Register-ObjectEvent.
 
 
.PARAMETER BookmarkStreamPath
    The full path and filename for the EventBookmark to be serialized and stored as a file.  The default Action 
    block will serialize and output the last EventBookmark object to the path specified.
    
    DEFAULT = ".\bookmark.stream"

    
.PARAMETER SourceIdentifier
    The SourceIdentifier for the event, which will be passed to Register-ObjectEvent.
    
    DEFAULT = "NewEventLog"
 
    
.PARAMETER Action
    Specifies commands to handle the events. The commands in the Action run when an event is raised, instead of 
    sending the event to the event queue. Enclose the commands in braces ( { } ) to create a script block.
    
    The value of the Action parameter can include the Automatic Variables already provided by Register-ObjectEvent 
    ($Event, $EventSubscriber, $Sender, $SourceEventArgs, and $SourceArgs).
    
    Register-EventRecordWrittenEvent also created the following additional Automatice Variables $EventRecord, 
    $EventRecordXML, $EventBookmark, $BookmarkStreamPath.  The variables are of the following types:
    
        EventRecord <System.Diagnostics.Eventing.Reader.EventRecord>
            - The Windows Log Event that raised the current EventRecordWritten Event.
            
        EventRecordXML <XML>
            - The XML representation of the current EventRecord, using the ToXml Method.
            - As an example, the EventData properties can be retrieved with $EventRecordXML.Event.EventData.Data 
            
        EventBookmark <System.Diagnostics.Eventing.Reader.EventBookmark>
            - The EventBookmark from the current EventRecord.
            - This EventBookmark placeholder is serialized and stored in the BookmarkStreamPath for 
              later retrieval, if the EventLogWatcher would need to be restarted from where it left off. 
               
        BookmarkStreamPath <string>
            - The full path and filename for the EventBookmark to be serialized and stored as a file.
            - Value matches the value of the same parameter that was passed to Register-EventRecordWrittenEvent
              at the time the event was registered.
            - This serialized EventBookmark can be used for retrieval, if the EventLogWatcher would need to be 
              restarted from where it left off.
              
    Any additional values required can be passed to the MessageData parameter for Register-EventRecordWrittenEvent.

    
.PARAMETER MessageData               
    Specifies any additional data to be associated with this event subscription. The value of this parameter appear
    s in the MessageData property of all events associated with this subscription.
    
    Multiple objects can be passed to this parameter using custom objects.  Build the custom object in using one of
    the following methods:
    
        METHOD 1
        
        $Object1 = "Some Data"
        $Object2 = "Other Data"
        $CustomObject = New-Object psobject -property @{'Object1' = $Object1; 'Object2' = $Object2}
        Register-EventRecordWrittenEvent $EventLogWatcher -Action $Action -MessageData $CustomObject
        
        METHOD 2
        
        $Object1 = "Some Data"
        $Object2 = "Other Data"
        $CustomObject = New-Object psobject
        $CustomObject | Add-Member noteproperty Object1 $Object1
        $CustomObject | Add-Member noteproperty Object2 $Object2
        Register-EventRecordWrittenEvent $EventLogWatcher -Action $Action -MessageData $CustomObject
        
    The data can then be accessed in the Action ScriptBlock with the following syntax:
    
        $event.MessageData.Object1
        $event.MessageData.Object2

.EXAMPLE
    C:\PS> $action = { write-host ("[ {0:g} ] Found Event {1} from {2} @ {3:g} " -f $Event.TimeGenerated,
    $EventRecord.RecordID,$EventRecord.Machinename,$EventRecord.TimeCreated) }
    C:\PS> Register-EventRecordWrittenEvent $EventLogWatcher -action $action
    
    C:\PS> $EventLogWatcher.Enabled = $True
    
    Description
    -----------
    This example will output using Write-Host for each EventRecordWritten Event that is raised by $EventLogWatcher, 
    and will serialize the last EventBookmark to the default location ".\bookmark.stream"  The saved EventBookmark
    can be used to restart the EventLogWatcher from where it left off if necessary.
    


.EXAMPLE
    C:\PS> $Action = {
               $EventRecord | 
               Select-Object TimeCreated, ID, Level, MachineName, RecordID | 
               Convertto-CSV -Outvariable OutData -NoTypeInformation 
               
               $Outdata[1..($Outdata.count - 1)] | 
               ForEach-Object {Out-File -InputObject $_ "c:\EventRecord.csv" -append}
           }
    C:\PS> Register-EventRecordWrittenEvent $EventLogWatcher -action $action
    
    C:\PS> $EventLogWatcher.Enabled = $True
    
    Description
    -----------
    This example will output to "C:\EventRecord.CSV" for each EventRecordWritten Event that is raised by 
    $EventLogWatcher, and will serialize the last EventBookmark to the default location ".\bookmark.stream" 
    The saved EventBookmark can be used to restart the EventLogWatcher from where it left off if necessary.
    
#>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True)]
        [System.Diagnostics.Eventing.Reader.EventLogWatcher]$InputObject,
        
        [Parameter(ValueFromPipelinebyPropertyName=$True)]
        [string]$BookmarkStreamPath = ".\bookmark.stream",
        
        [Parameter(ValueFromPipelinebyPropertyName=$True)]
        [String]$SourceIdentifier = "NewEventLog",
        
        [Parameter(ValueFromPipelinebyPropertyName=$True)]
        [ScriptBlock]$Action = $Null,
        
        [Parameter(ValueFromPipelinebyPropertyName=$True)]
        [psobject]$MessageData = $Null
                 
    )
    PROCESS
    {
        If ($BookmarkStreamPath.StartsWith(".\"))
        {
            $BookmarkStreamPath = (Convert-Path (Get-Location -PSProvider FileSystem)) + "\" + $BookmarkStreamPath.TrimStart(".\")
        }
        
        #---------------------------------------------------------------------------------------------------------
        # Check if any additional MessageData was passed, and either create new or append BookmarkStreamPath
        #---------------------------------------------------------------------------------------------------------
        If ($MessageData -eq $Null)
        {
            $MessageData = New-Object psobject -property @{
                BookmarkStreamPath = $BookmarkStreamPath;
            }
        } else {
            $MessageData | Add-Member noteproperty BookmarkStreamPath $BookmarkStreamPath -Force
        }
        
        #---------------------------------------------------------
        # Default action with automatic variables to be available
        #---------------------------------------------------------
        [ScriptBlock]$ObjectEventAction = {    
            $EventRecord = $EventArgs.EventRecord
            [XML]$EventRecordXML = $EventRecord.ToXML()
            
            $EventBookmark = $EventRecord.Bookmark
            $BookmarkStreamPath = $event.MessageData.BookmarkStreamPath
            
            Export-SerializedStream $EventBookmark $BookmarkStreamPath    
        }
        
        #--------------------------------------------------------------------------------
        # Check if any additional Action ScriptBlock was passed, and append if it exists
        #--------------------------------------------------------------------------------
        If ($Action -ne $Null)
        {
            $ObjectEventAction = [ScriptBlock]::Create($ObjectEventAction.ToString() + "`n" + $Action.ToString())
        }
        
        #----------------------------------------------------------------
        # Set ObjectEventParams to be Splatted into Register-ObjectEvent
        #----------------------------------------------------------------
        $ObjectEventParams = @{
            'InputObject' = $InputObject;
            'SourceIdentifier' = $SourceIdentifier;
            'EventName' = 'EventRecordWritten';
            'Action' = $ObjectEventAction;
            'MessageData' = $MessageData;
        }

        #----------------
        # Register Event
        #----------------
        Try
        {
            Register-ObjectEvent @ObjectEventParams
        }
        Catch [System.Exception]
        {
            Write-Error ("Error registereing EventRecordWritten Event`nERROR: {0}" -f $_.Exception.Message)
        }
    }
}

