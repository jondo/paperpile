package Paperpile::Exceptions;

use Exception::Class (PaperpileError,
                      FileError => { isa => 'PaperpileError' },
                      FileReadError => {isa => 'FileError'},
                      FileWriteError => {isa => 'FileError'},
                      FileFormatError => {isa => 'FileError'},
                      NetError => { isa => 'PaperpileError' },
                      NetGetError => { isa => 'NetError',
                                       fields => 'code',
                                     },
                      NetFormatError => { isa => 'NetError',
                                          fields => 'content',
                                        },

                     );

return 1;
