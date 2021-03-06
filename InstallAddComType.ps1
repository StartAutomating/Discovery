$cp = New-Object CodeDom.Compiler.CompilerParameters 
$cp.CompilerOptions = "/unsafe"
$null =$cp.ReferencedAssemblies.Add([object].Assembly.Location)
$null = $cp.ReferencedAssemblies.Add([psobject].Assembly.Location)

Add-Type -PassThru -CompilerParameters $cp -TypeDefinition @"
using System;
using System.IO;
using System.Text;
using System.Reflection;
using System.Reflection.Emit;
using System.Management.Automation;
using System.Collections.ObjectModel;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;


namespace n$(Get-Random) 
{
    [Cmdlet("Add", "ComType")]
    public class TestCmdletCommand : PSCmdlet
    {
        private string library;
        
        [Parameter(Mandatory=true,ParameterSetName="Library",ValueFromPipelineByPropertyName=true)]
        [Alias("FullName")]
        public string Library
        {
            get { return library; }
            set { this.library = value; }
        }
        
        private SwitchParameter passThru;
        
        [Parameter(ParameterSetName="Library",ValueFromPipelineByPropertyName=true)]
        public SwitchParameter PassThru
        {
            get { return this.passThru; }
            set { this.passThru = value; } 
        }

        private enum RegKind
        {
            RegKind_Default = 0,
            RegKind_Register = 1,
            RegKind_None = 2
        }
    
        [DllImport( "oleaut32.dll", CharSet = CharSet.Unicode, PreserveSig = false )]
        private static extern void LoadTypeLibEx( String strTypeLibName, RegKind regKind, 
        [MarshalAs( UnmanagedType.Interface )] out Object typeLib );

        protected override void BeginProcessing()
        {
        }
        
        protected override void ProcessRecord()
        {
            Object typeLib;
            LoadTypeLibEx( this.Library, RegKind.RegKind_None, out typeLib ); 
            
            if( typeLib == null )
            {
                ErrorRecord err = new ErrorRecord(new Exception("Could not load library:" + this.Library),"ExportIsoCommand.CouldNotLoad", ErrorCategory.OpenError, this.Library);
                WriteError(err);
                return;
            }
            
            TypeLibConverter converter = new TypeLibConverter();
            ConversionEventHandler eventHandler = new ConversionEventHandler();
            int lastSlash = this.Library.LastIndexOf("\\");
            string libName = this.Library;
            if (lastSlash != -1) {
                libName = this.Library.Substring(lastSlash + 1);   
            }
            AssemblyBuilder asm = converter.ConvertTypeLibToAssembly( typeLib, libName, 0, eventHandler, null, null, null, null );
            if (this.passThru) {
                this.WriteObject(asm.GetTypes(),true);
            }
            
        }
                
        protected override void EndProcessing()
        {
        
        }

    }
    
    class ConversionEventHandler : ITypeLibImporterNotifySink
    {
        public void ReportEvent( ImporterEventKind eventKind, int eventCode, string eventMsg )
        {
            // handle warning event here...
        }
        
        public Assembly ResolveRef( object typeLib )
        {
            // resolve reference here and return a correct assembly...
            return null; 
        }    
    }    
}
"@ |
    Select-object -expandProperty Assembly |
    Import-module
