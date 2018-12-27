            declare
               -- All found nearby globes are stored in Globes
               Globes                    : constant Energy_Globes := Energy_Globes_Around;
               -- The left charge of this vehicle.
               Charge_Left               : Real;
               -- They denote the globe which is the most closest to the vehicle
               -- and the distance to the globe respectively.
               Nearest_Globe             : Energy_Globe;
               Dist_to_Nearest           : Real;
               -- They are the latest recorded message and the message just being
               -- received by the vehicle respectively.
               Latest_Message_Recorded   : Inter_Vehicle_Messages;
               thisMessage               : Inter_Vehicle_Messages;
               -- This is a flag indicating whether the vehicle has received at
               -- least one message or not.
               First_Message             : Boolean := True;
               -- This value is the time difference between now and the time when
               -- message received.
               Interval_Until_Now        : Real;
               -- This means the time difference between this message and the latest
               -- recorded message.
               Interval_Between_Message  : Real;
               -- This is the distance between the vehicle and the globe contained in
               -- the latest message and the message respectively.
               Latest_Globe_Dist         : Real;
               this_Globe_Dist           : Real;

            begin
               -- Let vehicles go to the same place and be taken charge by our design
               -- pattern instantly.
               -- This idea is inspired by my friend Zeyuan Xu (u6342568).
               Set_Destination (The_Origin);
               Set_Throttle (Full_Throttle);
               -- If globes are detected, check them.
               if Globes'Length > 0 then
                  If_Nearby_Globes_Exist        := True;
                  Globe_Available               := Globes (Globes'First);
                  Nearest_Globe                 := Globes (Globes'First);
                  Dist_to_Nearest               := Real (abs ("-" (Globes (Globes'First).Position, Position)));
                  -- Check each of message, compare and store the best one
                  for Globe of Globes loop
                     thisMessage.Nearby_Globe      := Globe;
                     thisMessage.Sending_Time      := Clock;
                     thisMessage.Sender_No         := Vehicle_No;
                     thisMessage.Visible_Vehicles.Include (New_Item => Real (Vehicle_No));
                     -- Spreading this message to neighbors.
                     Send (thisMessage);
                     -- Get the nearest globe.
                     if Real (abs ("-" (thisMessage.Nearby_Globe.Position, Position))) <= Dist_to_Nearest then
                        Dist_to_Nearest := Real (abs ("-" (thisMessage.Nearby_Globe.Position, Position)));
                        Nearest_Globe   := thisMessage.Nearby_Globe;
                     end if;
                  end loop;

                  -- This section force the vehicle to fly towards the nearest globe founded
                  Set_Destination (Nearest_Globe.Position);
                  Set_Throttle (Full_Throttle);

                  -- if there is no globe founded, check whether these is new message
                  -- from others.
               else
                  -- Stop checking for messages only when there is no message.
                  while Messages_Waiting loop
                     -- Store the first message.
                     if First_Message then
                        Receive (Latest_Message_Recorded);
                        If_Nearby_Globes_Exist := True;
                        Globe_Available        := Latest_Message_Recorded.Nearby_Globe;
                        -- First message is been received.
                        First_Message          := False;
                        -- Start to collect information about other vehicles.
                        Visible_Population     := Latest_Message_Recorded.Visible_Vehicles;
                        Send (Latest_Message_Recorded);
                     else
                        Receive (thisMessage);
                        -- See if this message is the latest
                        Interval_Between_Message := Real (To_Duration (thisMessage.Sending_Time - Latest_Message_Recorded.Sending_Time));
                        -- Include this vehicle itself to the set.
                        Visible_Population.Include (New_Item => Real (Vehicle_No));
                        -- If the local set has difference with the one in message,
                        -- merge them together.
                        -- This part is inspired by our tutor Alex Smith.
                        if Visible_Population.Equivalent_Sets (Latest_Message_Recorded.Visible_Vehicles) = False then
                           Visible_Population.Union (Source => thisMessage.Visible_Vehicles);
                        end if;
                        -- Update the vehicle set in this message.
                        thisMessage.Visible_Vehicles := Visible_Population;

                        -- If the message is newer than the local one, update local information.
                        if Interval_Between_Message >= 0.0 then
                           Latest_Message_Recorded  := thisMessage;
                           If_Nearby_Globes_Exist   := True;
                           Globe_Available          := thisMessage.Nearby_Globe;
                           Send (thisMessage);

                           -- Otherwise compare the globe information to see if
                           -- the new message indicates a nearer globe.
                        else
                           Latest_Globe_Dist := Real (abs ("-" (Latest_Message_Recorded.Nearby_Globe.Position, Position)));
                           this_Globe_Dist   := Real (abs ("-" (thisMessage.Nearby_Globe.Position, Position)));
                           if this_Globe_Dist < Latest_Globe_Dist then
                              Interval_Until_Now := Real (To_Duration (Clock - thisMessage.Sending_Time));
                              -- If yes, continue to check if the message is too
                              -- archaic for now.
                              if Interval_Until_Now <= 1.0 then
                                 Latest_Message_Recorded := thisMessage;
                                 If_Nearby_Globes_Exist  := True;
                                 Globe_Available         := thisMessage.Nearby_Globe;
                                 Send (thisMessage);
                              end if;
                           end if;
                        end if;
                     end if;

                  end loop;

               end if;

               -- Move if a nearby globe exists.
               if If_Nearby_Globes_Exist then
                  -- The nearby globe is been chasing now if needed.
                  If_Nearby_Globes_Exist := False;
                  Charge_Left := Real (Current_Charge);

                  Interval_Until_Now := Real (To_Duration (Clock - Latest_Message_Recorded.Sending_Time));

                  -- If the number of vehicles that the vehicle knows is less than
                  -- the threshold, don't hesitate and keep two eyes on it.
                  if Integer (Visible_Population.Length) > Vehicle_Tot_Low_Threshold then
                     if Interval_Until_Now < Max_Time_Interval then
                        -- Parameters would be adjusted considering different charge.
                        if Charge_Left < Energy_Low_Threshold then
                           Set_Throttle (Full_Throttle);
                           Set_Destination (Globe_Available.Position);
                        elsif Charge_Left > Energy_High_Threshold then

                           Set_Throttle (Full_Throttle - Charge_Left / 1.2);
                           Set_Destination (0.5 * ("-" (Position, Globe_Available.Position)));
                        else

                           Set_Throttle (Full_Throttle - Charge_Left / 3.0);
                           Set_Destination (Globe_Available.Position);
                        end if;
                     end if;
                  else
                     Set_Destination (Globe_Available.Position);
                     Set_Throttle (Full_Throttle);
                  end if;

               end if;
            end;
