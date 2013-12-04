/**
 C Hook um den Kernel zu starten
 */
import kernel.kernel;

extern(C) {
	void kmain( ulong multibootMagic, ulong* multibootInfo ) {
		Kernel.Initialize( multibootMagic, multibootInfo );
	}
}