! Module   : gyre_scanpar
! Purpose  : frequency scan parameters
!
! Copyright 2013 Rich Townsend
!
! This file is part of GYRE. GYRE is free software: you can
! redistribute it and/or modify it under the terms of the GNU General
! Public License as published by the Free Software Foundation, version 3.
!
! GYRE is distributed in the hope that it will be useful, but WITHOUT
! ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
! or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
! License for more details.
!
! You should have received a copy of the GNU General Public License
! along with this program.  If not, see <http://www.gnu.org/licenses/>.

$include 'core.inc'
$include 'core_parallel.inc'

module gyre_scanpar

  ! Uses

  use core_kinds
  use core_parallel

  ! No implicit typing

  implicit none

  ! Derived-type definitions

  type :: scanpar_t
     real(WP)        :: freq_min
     real(WP)        :: freq_max
     integer         :: n_freq
     character(64)   :: grid_type
     character(64)   :: grid_frame
     character(64)   :: freq_units
     character(64)   :: freq_frame
     character(2048) :: tag_list
  end type scanpar_t

  ! Interfaces

  $if ($MPI)

  interface bcast
     module procedure bcast_0_
     module procedure bcast_1_
  end interface bcast

  interface bcast_alloc
     module procedure bcast_alloc_0_
     module procedure bcast_alloc_1_
  end interface bcast_alloc

  $endif

  ! Access specifiers

  private

  public :: scanpar_t
  public :: read_scanpar
  $if ($MPI)
  public :: bcast
  public :: bcast_alloc
  $endif

  ! Procedures

contains

  subroutine read_scanpar (unit, sp)

    integer, intent(in)                       :: unit
    type(scanpar_t), allocatable, intent(out) :: sp(:)

    integer                       :: n_sp
    integer                       :: i
    real(WP)                      :: freq_min
    real(WP)                      :: freq_max
    integer                       :: n_freq
    character(LEN(sp%freq_units)) :: freq_units
    character(LEN(sp%freq_frame)) :: freq_frame
    character(LEN(sp%grid_type))  :: grid_type
    character(LEN(sp%grid_frame)) :: grid_frame
    character(LEN(sp%tag_list))   :: tag_list

    namelist /scan/ freq_min, freq_max, n_freq, freq_units, freq_frame, &
         grid_type, grid_frame, tag_list

    ! Count the number of scan namelists

    rewind(unit)

    n_sp = 0

    count_loop : do
       read(unit, NML=scan, END=100)
       n_sp = n_sp + 1
    end do count_loop

100 continue

    ! Read scan parameters

    rewind(unit)

    allocate(sp(n_sp))

    read_loop : do i = 1, n_sp

       freq_min = 1._WP
       freq_max = 10._WP
       n_freq = 10
          
       freq_units = 'NONE'
       freq_frame = 'INERTIAL'

       grid_type = 'LINEAR'
       grid_frame = 'INERTIAL'

       tag_list = ''

       read(unit, NML=scan)

       ! Initialize the scanpar

       sp(i) = scanpar_t(freq_min=freq_min, &
                         freq_max=freq_max, &
                         n_freq=n_freq, &
                         freq_units=freq_units, &
                         freq_frame=freq_frame, &
                         grid_type=grid_type, &
                         grid_frame=grid_frame, &
                         tag_list=tag_list)

    end do read_loop

    ! Finish

    return

  end subroutine read_scanpar

!****

  $if ($MPI)

  $define $BCAST $sub

  $local $RANK $1

  subroutine bcast_${RANK}_ (sp, root_rank)

    type(scanpar_t), intent(inout) :: sp$ARRAY_SPEC($RANK)
    integer, intent(in)            :: root_rank

    ! Broadcast the scanpar_t

    call bcast(sp%freq_min, root_rank)
    call bcast(sp%freq_max, root_rank)
    call bcast(sp%n_freq, root_rank)

    call bcast(sp%grid_type, root_rank)
    call bcast(sp%freq_units, root_rank)
    call bcast(sp%freq_frame, root_rank)
    call bcast(sp%tag_list, root_rank)

    ! Finish

    return

  end subroutine bcast_${RANK}_

  $endsub

  $BCAST(0)
  $BCAST(1)

!****

  $BCAST_ALLOC(type(scanpar_t),0)
  $BCAST_ALLOC(type(scanpar_t),1)

  $endif

end module gyre_scanpar
