/**
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
module kernel.arch.architecture;

public
{
	version( X86_64 )
	{
		import kernel.arch.x86.cpu;
	}
	else version( X86 )
	{
		import kernel.arch.x86.cpu;
	}
}

class Architecture
{
	/**
	 Initialize common hardware structures
	 */
	public static bool Initialize()
	{
		Cpu.Initialize();
		
		Cpu.enableInterrupts();

		return true;
	}
}